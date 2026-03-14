"""Kokoro TTS engine wrapper — loads KPipeline once, generates WAV audio bytes."""

import io
import threading
import warnings

import numpy as np
import soundfile as sf

warnings.filterwarnings("ignore")

SAMPLE_RATE = 24000

# Available voices (Kokoro-82M)
VOICES = [
    "af_heart", "af_alloy", "af_aoede", "af_bella", "af_jessica", "af_kore",
    "af_nicole", "af_nova", "af_river", "af_sarah", "af_sky",
    "am_adam", "am_echo", "am_eric", "am_liam", "am_michael", "am_onyx",
    "am_puck", "am_santa",
    "bf_alice", "bf_emma", "bf_isabella", "bf_lily",
    "bm_daniel", "bm_fable", "bm_george", "bm_lewis",
]


class KokoroEngine:
    def __init__(self):
        self._pipeline = None
        self._lock = threading.Lock()

    def load(self):
        """Load the model. Call once on startup."""
        from kokoro import KPipeline
        self._pipeline = KPipeline(lang_code="a")

    def generate(self, text: str, voice: str = "af_heart", speed: float = 1.0) -> bytes:
        """Generate WAV audio bytes from text. Thread-safe."""
        if self._pipeline is None:
            raise RuntimeError("Engine not loaded. Call load() first.")

        with self._lock:
            generator = self._pipeline(text, voice=voice, speed=speed)
            audio_chunks = []
            for _gs, _ps, audio in generator:
                audio_chunks.append(audio)

        if not audio_chunks:
            raise ValueError("No audio generated — text may be empty or unparseable.")

        combined = np.concatenate(audio_chunks)

        buf = io.BytesIO()
        sf.write(buf, combined, SAMPLE_RATE, format="WAV")
        buf.seek(0)
        return buf.read()

    @staticmethod
    def list_voices() -> list[str]:
        return VOICES
