# macOS system-wide hotkey reader

A **serverless** way to read your current text selection aloud with Kokoro, in **every macOS app** — including Electron apps (VS Code, Slack, Discord) where the native Services menu doesn't reach.

This is a lighter alternative to the Chrome extension / menu-bar app in this repo: no HTTP server, no browser. It's a small local **Unix-socket daemon** that keeps the Kokoro-82M model warm, driven by a global hotkey via [Karabiner-Elements](https://karabiner-elements.pqrs.org/).

Press **⌥⌘S** on any selected text → it reads. Press again → it stops.

## How it works

```
⌥⌘S ─▶ Karabiner ─▶ real ⌘C (copies selection) ─▶ read-selection.sh
                                                        │
                                        pbpaste │ speak.sh
                                                        │
                                    warm Unix-socket daemon (kokoro-daemon.py)
                                                        │
                                                   afplay (audio)
```

The daemon keeps the model resident in RAM (~300 MB) and auto-shuts after 30 min idle. A launchd job warms it at login so the first read isn't a cold start.

## Files

| File | Role |
|------|------|
| `kokoro-daemon.py` | Keeps the model warm; serves generation requests over `/tmp/kokoro-daemon.sock`. Auto-shuts after 30 min idle. |
| `speak.sh` | Sends text to the daemon (or cold-starts if it's down), plays the result with `afplay`. |
| `warm.sh` | Starts the daemon if it isn't running. Idempotent. |
| `stop.sh` | Stops playback + daemon. |
| `read-selection.sh` | Entry point for the hotkey: reads stdin, warms, plays in the background, toggles stop. Serialized with a lock so rapid presses can't spawn duplicate daemons. |
| `com.kokoro.warmup.plist` | launchd agent — warms the daemon at login. |
| `karabiner-rule.json` | The ⌥⌘S rule (saves clipboard → real ⌘C → read → restores clipboard). |

## Setup

Assumes you already have a Kokoro venv at `~/Models/kokoro/.venv` with the `kokoro`, `soundfile`, and `numpy` packages, plus `terminal-notifier` (`brew install terminal-notifier`).

1. **Install the scripts** to `~/Models/kokoro/` and make them executable:
   ```bash
   cp macos-hotkey/{kokoro-daemon.py,speak.sh,warm.sh,stop.sh,read-selection.sh} ~/Models/kokoro/
   chmod +x ~/Models/kokoro/*.sh
   ```

2. **Warm at login** — edit `com.kokoro.warmup.plist`, replace `YOUR_USERNAME`, then:
   ```bash
   cp macos-hotkey/com.kokoro.warmup.plist ~/Library/LaunchAgents/com.kokoro.kokoro-reader-warmup.plist
   sed -i '' "s/YOUR_USERNAME/$USER/g" ~/Library/LaunchAgents/com.kokoro.kokoro-reader-warmup.plist
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.kokoro.kokoro-reader-warmup.plist
   ```

3. **The hotkey** — in Karabiner-Elements, add the rule from `karabiner-rule.json` to
   `~/.config/karabiner/karabiner.json` under `profiles[].complex_modifications.rules`
   (replace `YOUR_USERNAME` first). Validate with:
   ```bash
   "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli" \
     --lint-complex-modifications macos-hotkey/karabiner-rule.json
   ```

4. Select text anywhere → **⌥⌘S**.

## Gotchas we paid for (so you don't have to)

These cost real debugging time on **macOS 15 Sequoia**:

- **Electron apps never show macOS Services** in their right-click menu (VS Code, Slack, Chrome page area). A Services-based Quick Action works only in native AppKit apps. The hotkey approach here sidesteps that.

- **Sequoia silently blocks synthetic keystrokes.** `osascript … keystroke "c"` fails with *"not allowed to send keystrokes (1002)"* and **does not prompt** for permission — it just fails. So any "copy the selection" reader built on Shortcuts.app or an Automator Service dies here. Karabiner avoids it entirely because it injects a **real HID ⌘C**, not an AppleEvent.

- **Non-UTF-8 launch environment mangles text.** Karabiner and launchd run shell commands with a minimal locale, so em dashes / smart quotes / curly apostrophes decode into broken surrogates (`'utf-8' codec can't encode … surrogates not allowed`) and produce silent `AudioFileOpen failed` errors. The fix: pass text to Python as **raw bytes over stdin** and `sys.stdin.buffer.read().decode("utf-8")`, with `json.dumps(..., ensure_ascii=False)`. Never interpolate selected text into a `python -c` string, and don't rely on `PYTHONUTF8`/`LANG` alone. (ASCII test sentences work fine, which masks this bug — always test with real prose.)

- **launchd reaps orphaned daemons.** `warm.sh` starts the daemon then exits; without `AbandonProcessGroup` in the plist, launchd kills the daemon when the job finishes.

- **`mktemp` templates need trailing X's.** `mktemp /tmp/kokoro-XXXXX.wav` (X's not at the end) collides under rapid fire on macOS. Use a unique name like `/tmp/kokoro-$$-$RANDOM.wav`.

## Notes

- The hotkey momentarily uses the clipboard to grab the selection, then **restores your previous clipboard** (text only — a copied image won't survive).
- Requires the `left_option → left_command` remap? No — but if you *have* such a remap, remember a real Option only exists on your **right** Option key.
