#!/bin/zsh
# Speak text using Kokoro TTS
# Uses the warm daemon if running, otherwise falls back to cold start
#
# Usage: echo "text" | ~/Models/kokoro/speak.sh
#    or: ~/Models/kokoro/speak.sh "text to speak"
#    or: ~/Models/kokoro/speak.sh -v am_adam "text with different voice"
#    or: ~/Models/kokoro/speak.sh -s 1.5 "speak faster"
#    or: ~/Models/kokoro/speak.sh -s 2 -v am_adam "fast + different voice"

VOICE="af_heart"
SPEED="1.0"
VENV=~/Models/kokoro/.venv/bin/python3
TMPFILE="/tmp/kokoro-$$-${RANDOM}.wav"
STOP_SCRIPT=~/Models/kokoro/stop.sh
SOCKET=/tmp/kokoro-daemon.sock

# Parse flags
while [[ "$1" == -* ]]; do
    case "$1" in
        -v) VOICE="$2"; shift 2 ;;
        -s) SPEED="$2"; shift 2 ;;
        *) shift ;;
    esac
done

if [ -n "$1" ]; then
    TEXT="$1"
else
    TEXT=$(cat)
fi

# Force UTF-8 so non-ASCII selections (em dashes, smart quotes, curly apostrophes)
# decode correctly even when launched from a minimal env (Karabiner / launchd).
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 PYTHONUTF8=1

# Text is passed to Python as RAW BYTES over stdin and decoded UTF-8 explicitly.
# This is locale-proof — no env/shell boundary to mangle em dashes or smart quotes.

# Try warm daemon first
if [ -S "$SOCKET" ]; then
    response=$(print -r -- "$TEXT" | "$VENV" -c "
import socket, json, sys
text = sys.stdin.buffer.read().decode('utf-8', 'replace')
sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect('$SOCKET')
sock.sendall(json.dumps({'text': text, 'voice': '$VOICE', 'output': '$TMPFILE'}, ensure_ascii=False).encode('utf-8'))
sock.shutdown(socket.SHUT_WR)
result = sock.recv(1024).decode()
sock.close()
sys.exit(0 if result == 'ok' else 1)
" 2>/dev/null)
    daemon_ok=$?
fi

# Fall back to cold start if daemon unavailable or failed
if [ ! -S "$SOCKET" ] || [ "${daemon_ok:-1}" -ne 0 ]; then
    print -r -- "$TEXT" | "$VENV" -c "
import warnings, sys
warnings.filterwarnings('ignore')
text = sys.stdin.buffer.read().decode('utf-8', 'replace')
from kokoro import KPipeline
import soundfile as sf

pipeline = KPipeline(lang_code='a')
generator = pipeline(text, voice='$VOICE')
audio_chunks = []
for gs, ps, audio in generator:
    audio_chunks.append(audio)
import numpy as np
sf.write('$TMPFILE', np.concatenate(audio_chunks), 24000)
" 2>/dev/null
fi

# Show notification with stop button
terminal-notifier \
    -title "Kokoro" \
    -subtitle "Speed: ${SPEED}x · Voice: $VOICE" \
    -message "${TEXT:0:40}..." \
    -execute "$STOP_SCRIPT" \
    -group "kokoro-tts" \
    -sound "" \
    2>/dev/null &

# Play audio at specified speed
afplay -r "$SPEED" "$TMPFILE"

# Clean up notification and temp file
terminal-notifier -remove "kokoro-tts" 2>/dev/null
rm -f "$TMPFILE"
