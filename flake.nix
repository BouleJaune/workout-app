# github:tonuser/workout-tracker — flake.nix
{
  description = "Workout & nutrition tracker — NixOS module";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    workoutModule = { config, pkgs, lib, ... }:
    with lib;
    let
      cfg = config.services.workout;

      pythonEnv = pkgs.python3.withPackages (ps: with ps; [
        fastapi
        uvicorn
        pydantic
      ]);

      workoutPkg = pkgs.runCommand "workout-app" { } ''
        mkdir -p $out
        cp ${self}/main.py      $out/main.py
        cp ${self}/workout.html $out/workout.html
      '';

    in {
      options.services.workout = {
        enable = mkEnableOption "workout tracker";

        port = mkOption {
          type    = types.port;
          default = 8420;
          description = "Port d'écoute de l'API (localhost only).";
        };

        nginxVhost = mkOption {
          type    = types.str;
          example = "workout.nixos";
          description = "Virtualhost nginx dédié à l'app.";
        };
      };

        forceSSL = mkOption {
          type    = types.bool;
          default = true;
        };

        enableACME = mkOption {
          type    = types.bool;
          default = true;
        };

      config = mkIf cfg.enable {

        systemd.services.workout = {
          description = "Workout Tracker API";
          after       = [ "network.target" ];
          wantedBy    = [ "multi-user.target" ];

          serviceConfig = {
            ExecStart = "${pythonEnv}/bin/uvicorn main:app --host 127.0.0.1 --port ${toString cfg.port}";

            WorkingDirectory = workoutPkg;

            Environment = [
              "WORKOUT_HTML=${workoutPkg}/workout.html"
              "WORKOUT_DATA=/var/lib/workout/data.json"
            ];

            StateDirectory        = "workout";
            DynamicUser           = true;
            Restart               = "on-failure";
            RestartSec            = "5s";
            ProtectSystem         = "strict";
            ProtectHome           = true;
            NoNewPrivileges       = true;
            PrivateTmp            = true;
            CapabilityBoundingSet = "";
          };
        };

        services.nginx.virtualHosts.${cfg.nginxVhost} = {
          locations."/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.port}";
            forceSSL = cfg.forceSSL;
            enableACME = cfg.enableACME;
            extraConfig = ''
              proxy_set_header Host              $host;
              proxy_set_header X-Real-IP         $remote_addr;
              proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
            '';
          };
        };

      };
    };

  in {
    nixosModules.default = workoutModule;
    nixosModules.workout = workoutModule;
  };
}
