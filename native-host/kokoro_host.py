#!/usr/bin/env python3
"""Native messaging host for Kokoro Reader Chrome extension.
Handles start/stop of the TTS server from the browser UI."""

import json
import os
import signal
import struct
import subprocess
import sys
import urllib.request

SERVER_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "server")
PID_FILE = "/tmp/kokoro-server.pid"
SERVER_URL = "http://localhost:8787"


def send_message(msg):
    encoded = json.dumps(msg).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("I", len(encoded)))
    sys.stdout.buffer.write(encoded)
    sys.stdout.buffer.flush()


def read_message():
    raw_length = sys.stdin.buffer.read(4)
    if not raw_length:
        return None
    length = struct.unpack("I", raw_length)[0]
    data = sys.stdin.buffer.read(length)
    return json.loads(data.decode("utf-8"))


def is_server_running():
    try:
        req = urllib.request.Request(f"{SERVER_URL}/api/health", method="GET")
        with urllib.request.urlopen(req, timeout=2) as resp:
            data = json.loads(resp.read())
            return data.get("status") == "ok"
    except Exception:
        return False


def get_pid():
    try:
        with open(PID_FILE, "r") as f:
            return int(f.read().strip())
    except (FileNotFoundError, ValueError):
        return None


def start_server():
    if is_server_running():
        return {"status": "running", "message": "Server already running"}

    # Find the venv
    venv = os.path.join(SERVER_DIR, ".venv", "bin", "activate")
    if not os.path.exists(venv):
        # Fall back to the Models/kokoro venv
        venv = os.path.expanduser("~/Models/kokoro/.venv/bin/activate")

    cmd = f"source '{venv}' && cd '{SERVER_DIR}' && uvicorn app:app --host 0.0.0.0 --port 8787"
    proc = subprocess.Popen(
        ["bash", "-c", cmd],
        stdout=open("/tmp/kokoro-server.log", "w"),
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )

    with open(PID_FILE, "w") as f:
        f.write(str(proc.pid))

    # Wait a bit for startup
    import time
    for _ in range(15):
        time.sleep(1)
        if is_server_running():
            return {"status": "running", "message": "Server started"}

    return {"status": "error", "message": "Server failed to start — check /tmp/kokoro-server.log"}


def stop_server():
    pid = get_pid()
    if pid:
        try:
            os.killpg(os.getpgid(pid), signal.SIGTERM)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            os.unlink(PID_FILE)
        except FileNotFoundError:
            pass

    # Also kill any uvicorn on 8787
    subprocess.run(["bash", "-c", "lsof -ti :8787 | xargs kill 2>/dev/null"], capture_output=True)

    return {"status": "stopped", "message": "Server stopped"}


LAUNCHD_LABEL = "com.kokoro.tts-server"
LAUNCHD_PLIST = os.path.expanduser(f"~/Library/LaunchAgents/{LAUNCHD_LABEL}.plist")


def enable_launch_at_login():
    # Find the venv
    venv = os.path.join(SERVER_DIR, ".venv", "bin", "activate")
    if not os.path.exists(venv):
        venv = os.path.expanduser("~/Models/kokoro/.venv/bin/activate")

    plist = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>{LAUNCHD_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>-c</string>
        <string>source '{venv}' &amp;&amp; cd '{SERVER_DIR}' &amp;&amp; exec uvicorn app:app --host 0.0.0.0 --port 8787</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>10</integer>
    <key>StandardOutPath</key>
    <string>/tmp/kokoro-server.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/kokoro-server.log</string>
</dict>
</plist>"""

    os.makedirs(os.path.dirname(LAUNCHD_PLIST), exist_ok=True)
    with open(LAUNCHD_PLIST, "w") as f:
        f.write(plist)

    subprocess.run(["launchctl", "load", LAUNCHD_PLIST], capture_output=True)
    return {"status": "running", "message": "Launch at login enabled"}


def disable_launch_at_login():
    if os.path.exists(LAUNCHD_PLIST):
        subprocess.run(["launchctl", "unload", LAUNCHD_PLIST], capture_output=True)
        os.unlink(LAUNCHD_PLIST)
    return {"status": "stopped", "message": "Launch at login disabled"}


def main():
    while True:
        msg = read_message()
        if msg is None:
            break

        action = msg.get("action", "")

        if action == "status":
            running = is_server_running()
            send_message({"status": "running" if running else "stopped"})
        elif action == "start":
            send_message(start_server())
        elif action == "stop":
            send_message(stop_server())
        elif action == "restart":
            stop_server()
            import time
            time.sleep(1)
            send_message(start_server())
        elif action == "enable_launch":
            send_message(enable_launch_at_login())
        elif action == "disable_launch":
            send_message(disable_launch_at_login())
        else:
            send_message({"status": "error", "message": f"Unknown action: {action}"})


if __name__ == "__main__":
    main()
