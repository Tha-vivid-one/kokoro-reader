#!/bin/zsh
# Start the Kokoro TTS daemon if not already running
# Usage: ~/Models/kokoro/warm.sh

# Force UTF-8 so the daemon decodes non-ASCII text correctly even when started
# from a minimal env (Karabiner shell_command / launchd warm-at-login).
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 PYTHONUTF8=1

DAEMON=~/Models/kokoro/kokoro-daemon.py
VENV=~/Models/kokoro/.venv/bin/python3
PID_FILE=/tmp/kokoro-daemon.pid
SOCKET=/tmp/kokoro-daemon.sock

# Check if daemon is already running
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        # Already running, check socket exists too
        if [ -S "$SOCKET" ]; then
            exit 0
        fi
        # PID alive but socket gone — kill and restart
        kill "$pid" 2>/dev/null
    fi
    # Stale PID file
    rm -f "$PID_FILE"
fi

# Start daemon in background, wait for "ready" signal
"$VENV" "$DAEMON" &
daemon_pid=$!

# Wait up to 30s for the socket to appear (model loading)
for i in {1..60}; do
    if [ -S "$SOCKET" ]; then
        echo "Kokoro daemon ready (PID $daemon_pid)"
        exit 0
    fi
    sleep 0.5
done

echo "Daemon failed to start" >&2
kill "$daemon_pid" 2>/dev/null
exit 1
