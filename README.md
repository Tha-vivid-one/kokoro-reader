# Kokoro Reader

A Chrome extension + self-hosted TTS server. Select text on any webpage, right-click **"Read aloud with Kokoro"**, and hear it spoken back using the [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M) model.

Fully open source — run the server anywhere, use the extension in Chrome.

## Quick Start

### 1. Start the server

```bash
# Clone the repo
git clone https://github.com/Tha-vivid-one/kokoro-reader.git
cd kokoro-reader

# Create .env from example
cp server/.env.example server/.env
# Edit server/.env — set your API_KEY

# Start with Docker
docker compose up -d
```

The server runs at `http://localhost:8787`. First startup downloads the model (~330MB).

### 2. Install the extension

1. Open Chrome → `chrome://extensions`
2. Enable **Developer mode** (top right)
3. Click **Load unpacked** → select the `extension/` folder
4. Click the Kokoro Reader icon → set your server URL and API key

### 3. Use it

Select text on any page → right-click → **"Read aloud with Kokoro"**

A floating player appears in the bottom-right corner with pause/stop controls.

## Server API

All endpoints require `X-API-Key` header (if `API_KEY` is set in `.env`).

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/tts` | POST | Generate speech. Body: `{"text": "...", "voice": "af_heart", "speed": 1.0}`. Returns WAV audio. |
| `/api/voices` | GET | List available voices. |
| `/api/health` | GET | Health check. |

### Test with curl

```bash
curl -X POST http://localhost:8787/api/tts \
  -H "X-API-Key: your-key" \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello world"}' \
  --output test.wav
```

## Configuration

### Server (`server/.env`)

| Variable | Default | Description |
|----------|---------|-------------|
| `API_KEY` | *(empty)* | API key for authentication. Empty = no auth. |
| `RATE_LIMIT` | `10` | Max requests per minute per API key. |

### Extension (popup settings)

- **Server URL** — where your Kokoro TTS server is running
- **API Key** — matches the server's `API_KEY`
- **Voice** — fetched from the server's `/api/voices` endpoint
- **Speed** — 0.5x to 2.0x

## Voices

28 voices available across American English (af_/am_) and British English (bf_/bm_):

`af_heart`, `af_alloy`, `af_aoede`, `af_bella`, `af_jessica`, `af_kore`, `af_nicole`, `af_nova`, `af_river`, `af_sarah`, `af_sky`, `am_adam`, `am_echo`, `am_eric`, `am_liam`, `am_michael`, `am_onyx`, `am_puck`, `am_santa`, `bf_alice`, `bf_emma`, `bf_isabella`, `bf_lily`, `bm_daniel`, `bm_fable`, `bm_george`, `bm_lewis`

## Running without Docker

```bash
cd server
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# espeak-ng must be installed (brew install espeak-ng / apt install espeak-ng)
API_KEY=your-key uvicorn app:app --host 0.0.0.0 --port 8787
```

## License

MIT
