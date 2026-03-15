import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyService = HotkeyService.shared
    private let player = AudioPlayerService.shared
    private let ttsService = TTSService.shared
    private let textCapture = TextCaptureService.shared

    private(set) lazy var floatingWindow = FloatingWindowController(
        player: player,
        settings: SettingsService.shared
    )

    var isToolbarVisible: Bool { floatingWindow.isVisible }

    func toggleToolbar() {
        floatingWindow.toggle()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotkeys()
        hotkeyService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyService.stop()
        player.stop()
    }

    private func setupHotkeys() {
        hotkeyService.onReadSelection = { [weak self] in
            self?.readSelection()
        }
        hotkeyService.onPlayPause = { [weak self] in
            self?.player.togglePlayPause()
        }
        hotkeyService.onStop = { [weak self] in
            self?.player.stop()
        }
        hotkeyService.onSkipForward = { [weak self] in
            self?.player.skipForward()
        }
        hotkeyService.onSkipBackward = { [weak self] in
            self?.player.skipBackward()
        }
    }

    func readSelection() {
        guard let text = textCapture.captureSelectedText(), !text.isEmpty else { return }
        synthesizeAndPlay(text)
    }

    func readClipboard() {
        guard let text = textCapture.clipboardText(), !text.isEmpty else { return }
        synthesizeAndPlay(text)
    }

    private func synthesizeAndPlay(_ text: String) {
        player.stop()

        Task { @MainActor in
            do {
                if text.count > 4500 {
                    let segments = try await ttsService.synthesizeChunked(text: text)
                    player.playQueue(segments, preview: text)
                } else {
                    let data = try await ttsService.synthesize(text: text)
                    player.playData(data, preview: text)
                }
            } catch {
                // Player stays idle on error
            }
        }
    }
}
