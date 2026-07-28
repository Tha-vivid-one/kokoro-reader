#!/bin/zsh
# Read the current text selection aloud with Kokoro TTS.
# Invoked by the Karabiner ⌥⌘S rule as:  pbpaste | read-selection.sh
# Also accepts text as an argument.

LOG=~/Models/kokoro/read-selection.log
LOCK=/tmp/kokoro-reader.lock

if [ -n "$1" ]; then
    TEXT="$*"
else
    TEXT=$(cat)
fi

# Toggle: if Kokoro is already reading, this press stops it (and frees the lock).
if pgrep -f "afplay -r" >/dev/null 2>&1; then
    ~/Models/kokoro/stop.sh >/dev/null 2>&1
    rmdir "$LOCK" 2>/dev/null
    exit 0
fi

# Nothing selected — bail quietly.
[ -z "${TEXT//[[:space:]]/}" ] && exit 0

# Clear a stale lock (left behind by a crashed run) older than 2 minutes.
if [ -d "$LOCK" ] && [ -n "$(find "$LOCK" -maxdepth 0 -mmin +2 2>/dev/null)" ]; then
    rmdir "$LOCK" 2>/dev/null
fi

# Serialize: if a read is already being set up or playing, skip this press.
# This is what prevents a flurry of keypresses from spawning multiple daemons.
mkdir "$LOCK" 2>/dev/null || exit 0

{
    echo "$(date '+%Y-%m-%d %H:%M:%S') — reading ${#TEXT} chars"
    ~/Models/kokoro/warm.sh                       # idempotent; brings daemon up if cold
    print -r -- "$TEXT" | ~/Models/kokoro/speak.sh
    rmdir "$LOCK" 2>/dev/null
} >>"$LOG" 2>&1 &

exit 0
