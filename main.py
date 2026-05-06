import os
from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from pathlib import Path
import json

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Injectés par le service systemd via Environment=
# HTML vient du nix store (read-only), data est mutable dans StateDirectory
try:
    DATA_FILE = Path(os.environ["WORKOUT_DATA"])
except Exception:
    DATA_FILE = Path("./data.json")

try:
    HTML_FILE = Path(os.environ["WORKOUT_HTML"])
except Exception:
    HTML_FILE = Path("./workout.html")

DEFAULT_DATA = {
    "state": {},
    "nutri": {},
    "targets": {"cal": 2600, "prot": 110}
}


def load_data() -> dict:
    if DATA_FILE.exists():
        try:
            return json.loads(DATA_FILE.read_text())
        except Exception:
            pass
    return DEFAULT_DATA.copy()


def save_data(data: dict):
    DATA_FILE.parent.mkdir(parents=True, exist_ok=True)
    DATA_FILE.write_text(json.dumps(data))


class WorkoutData(BaseModel):
    state: dict
    nutri: dict
    targets: dict


@app.get("/api/data")
def get_data():
    return load_data()


@app.post("/api/data")
def post_data(data: WorkoutData):
    save_data(data.model_dump())
    return {"ok": True}


@app.get("/")
def serve_html():
    return FileResponse(HTML_FILE)
