FROM python:3.12-slim

# espeak-ng is required by misaki for phoneme generation
RUN apt-get update && \
    apt-get install -y --no-install-recommends espeak-ng && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Pre-download model so it's baked into the image
RUN python -c "from huggingface_hub import snapshot_download; snapshot_download('hexgrad/Kokoro-82M')"

COPY . .

EXPOSE 8787

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8787"]
