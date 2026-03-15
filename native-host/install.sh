#!/bin/bash
# Install the native messaging host for Kokoro Reader
# Usage: ./install.sh <chrome-extension-id>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOST_NAME="com.kokoro.reader"
HOST_SCRIPT="$SCRIPT_DIR/kokoro_host.py"
MANIFEST_SRC="$SCRIPT_DIR/$HOST_NAME.json"

# Chrome native messaging hosts directory
NATIVE_MSG_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"

if [ -z "$1" ]; then
    echo "Usage: ./install.sh <chrome-extension-id>"
    echo ""
    echo "Find your extension ID at chrome://extensions (enable Developer mode)"
    exit 1
fi

EXT_ID="$1"

mkdir -p "$NATIVE_MSG_DIR"

# Write manifest with correct path and extension ID
cat > "$NATIVE_MSG_DIR/$HOST_NAME.json" <<EOF
{
  "name": "$HOST_NAME",
  "description": "Kokoro Reader TTS Server Manager",
  "path": "$HOST_SCRIPT",
  "type": "stdio",
  "allowed_origins": [
    "chrome-extension://$EXT_ID/"
  ]
}
EOF

echo "Native messaging host installed."
echo "  Manifest: $NATIVE_MSG_DIR/$HOST_NAME.json"
echo "  Host: $HOST_SCRIPT"
echo "  Extension ID: $EXT_ID"
echo ""
echo "Reload the extension in Chrome to connect."
