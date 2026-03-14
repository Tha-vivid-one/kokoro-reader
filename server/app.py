"""FastAPI server for Kokoro TTS."""

import os
import time
from collections import defaultdict
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from tts import KokoroEngine

engine = KokoroEngine()

# Rate limiting state
_rate_limits: dict[str, list[float]] = defaultdict(list)
RATE_LIMIT = int(os.getenv("RATE_LIMIT", "10"))
RATE_WINDOW = 60  # seconds


@asynccontextmanager
async def lifespan(app: FastAPI):
    engine.load()
    yield


app = FastAPI(title="Kokoro TTS Server", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET", "OPTIONS"],
    allow_headers=["*"],
)

API_KEY = os.getenv("API_KEY", "")


def check_api_key(request: Request) -> str:
    if not API_KEY:
        return "no-auth"
    key = request.headers.get("X-API-Key", "")
    if key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")
    return key


def check_rate_limit(key: str):
    now = time.time()
    timestamps = _rate_limits[key]
    # Prune old entries
    _rate_limits[key] = [t for t in timestamps if now - t < RATE_WINDOW]
    if len(_rate_limits[key]) >= RATE_LIMIT:
        raise HTTPException(status_code=429, detail="Rate limit exceeded")
    _rate_limits[key].append(now)


class TTSRequest(BaseModel):
    text: str = Field(..., max_length=5000)
    voice: str = Field(default="af_heart")
    speed: float = Field(default=1.0, ge=0.5, le=2.0)


@app.post("/api/tts")
async def tts(request: Request, body: TTSRequest):
    key = check_api_key(request)
    check_rate_limit(key)

    if not body.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    if body.voice not in engine.list_voices():
        raise HTTPException(status_code=400, detail=f"Unknown voice: {body.voice}")

    try:
        audio_bytes = engine.generate(body.text, voice=body.voice, speed=body.speed)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    return Response(content=audio_bytes, media_type="audio/wav")


@app.get("/api/voices")
async def voices(request: Request):
    check_api_key(request)
    return {"voices": engine.list_voices()}


@app.get("/api/health")
async def health():
    return {"status": "ok", "model_loaded": engine._pipeline is not None}
