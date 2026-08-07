# STATE — updated 2026-08-07 by /wrap

## Open threads
- Watch hotkey reliability over the next few days — the watchdog + tap re-enable fix is new. If ⌘⇧R ever dies again, `tail ~/Library/Logs/KokoroReader/app.log` first; it now logs tap lifecycle, capture path, and TTS errors.
- ⌘C-simulation capture restores plain text only — rich clipboard content (images, formatting) is lost if a read is triggered while it's on the clipboard. Fine for now; fix is saving all pasteboard types.
- Builds are now signed with "Developer ID Application: Jarrett Truett (3KQH92CNXV)" via manual `codesign --force --deep --sign` after xcodebuild. Consider moving the identity into the Xcode project settings so the manual step disappears.

## Decisions this session
- Sign with Developer ID (not ad-hoc) so TCC Accessibility grants survive rebuilds — re-granting after every build was the recurring breakage.
- Stream long texts chunk-by-chunk (first chunk plays ~immediately) instead of synthesizing everything up front; generation counter on the player rejects stale producers after stop.
- Floating toolbar auto-shows on playback, auto-hides 1.5s after end; speed is a dropdown slider (0.5–2.0x) applied live via AVAudioPlayer rate; KOKORO logo text removed.
- File logging at ~/Library/Logs/KokoroReader/app.log (FileLog.swift) — `log show` was unusable for debugging this app.
- Model check 2026-08-07: kokoro 0.9.4 + Kokoro-82M v1.0 (commit f3ff357) is current upstream; no newer model exists.

## Next step
- Use it normally; if the bar or hotkeys misbehave, read app.log and iterate from there.
