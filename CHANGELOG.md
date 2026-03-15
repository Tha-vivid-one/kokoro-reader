# Changelog

## [1.2.0] - 2026-03-14

### Added
- Unified design system (KokoroTheme) across macOS app and Chrome extension
- Dark OLED palette: #0a0a14 base, #8b8bcd indigo accent, gradient progress bars
- Branded header with "KOKORO READER" identity
- Custom toggle switches and styled range sliders in extension popup
- Hover states on action buttons in menu bar
- Themed shortcut badges and section headers in settings

### Changed
- Complete redesign of Chrome extension popup to match content toolbar aesthetic
- PlayerView, MenuBarView, SettingsView, FloatingToolbarView all use shared theme tokens
- Consistent typography: monospaced digits, uppercase section labels, system font hierarchy

## [1.1.0] - 2026-03-14

### Added
- Floating toolbar — always-on-top player bar with transport controls, seekable progress bar, voice/speed selectors, and settings popover
- Toggle floating toolbar from menu bar
- Native messaging host for Chrome extension communication
- Toolbar is draggable and persists across spaces and fullscreen apps

### Changed
- Updated Chrome extension popup UI
- Updated extension background and content scripts

## [1.0.0] - 2026-03-14

### Added
- Self-hosted TTS server using Kokoro-82M model
- Chrome extension with right-click "Read aloud" and floating player
- macOS menu bar app with global keyboard shortcuts
- Accessibility API text capture with clipboard fallback
- Queue playback for long text (auto-chunking)
- 28 voices (American + British English)
- Docker support
- Configurable voice, speed, skip interval, launch at login
