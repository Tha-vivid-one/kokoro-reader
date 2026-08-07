import AppKit
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotkeyService = HotkeyService.shared
    private let player = AudioPlayerService.shared
    private let ttsService = TTSService.shared
    private let textCapture = TextCaptureService.shared
    private let log = Logger(subsystem: "com.kokoro.reader", category: "app")
    private var appNapActivity: NSObjectProtocol?

    private(set) lazy var floatingWindow = FloatingWindowController(
        player: player,
        settings: SettingsService.shared
    )

    var isToolbarVisible: Bool { floatingWindow.isVisible }

    func toggleToolbar() {
        floatingWindow.toggle()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // App Nap suspends background menu-bar apps, which stalls the event tap
        // callback until macOS disables the tap entirely. Opt out (doesn't block
        // system sleep — only process throttling).
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep,
            reason: "Global hotkey event tap must stay responsive"
        )
        setupHotkeys()
        hotkeyService.start()
        setupToolbarAutoShow()
    }

    private var toolbarHideWork: DispatchWorkItem?

    /// Pop the floating toolbar up while reading, drop it when playback ends.
    /// The hide is delayed slightly so a streaming gap between chunks doesn't
    /// flicker the bar.
    private func setupToolbarAutoShow() {
        player.onPlaybackStarted = { [weak self] in
            self?.toolbarHideWork?.cancel()
            self?.toolbarHideWork = nil
            self?.floatingWindow.show()
        }
        player.onPlaybackEnded = { [weak self] in
            guard let self else { return }
            toolbarHideWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.player.state == .idle else { return }
                self.floatingWindow.hide()
            }
            toolbarHideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
        }
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
            self?.synthesisTask?.cancel()
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
        // Capture can block (AX on large selections, ⌘C fallback waits on the
        // clipboard) — keep it off the main thread.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            guard let text = self.textCapture.captureSelectedText(), !text.isEmpty else {
                FileLog.log("readSelection: no text captured — nothing to play")
                return
            }
            DispatchQueue.main.async { self.synthesizeAndPlay(text) }
        }
    }

    func readClipboard() {
        guard let text = textCapture.clipboardText(), !text.isEmpty else {
            FileLog.log("readClipboard: clipboard empty — nothing to play")
            return
        }
        synthesizeAndPlay(text)
    }

    private var synthesisTask: Task<Void, Never>?

    private func synthesizeAndPlay(_ text: String) {
        synthesisTask?.cancel()
        player.stop()
        player.synthesisSpeed = SettingsService.shared.speed

        synthesisTask = Task { @MainActor in
            do {
                if text.count > 4500 {
                    // Stream: play the first chunk as soon as it's ready instead of
                    // synthesizing everything up front (long texts looked "dead").
                    let chunks = ttsService.chunkText(text)
                    FileLog.log("tts: \(text.count) chars → \(chunks.count) chunks, streaming")
                    var generation: Int?
                    for (index, chunk) in chunks.enumerated() {
                        if Task.isCancelled {
                            FileLog.log("tts: cancelled at chunk \(index + 1)/\(chunks.count)")
                            return
                        }
                        let data = try await ttsService.synthesize(text: chunk)
                        if let generation {
                            if !player.appendToQueue(data, generation: generation) {
                                FileLog.log("tts: playback stopped — dropping remaining \(chunks.count - index) chunks")
                                return
                            }
                        } else {
                            player.playData(data, preview: text)
                            generation = player.generation
                            FileLog.log("tts: playing chunk 1/\(chunks.count)")
                        }
                    }
                    FileLog.log("tts: all \(chunks.count) chunks delivered")
                } else {
                    FileLog.log("tts: synthesizing \(text.count) chars")
                    let data = try await ttsService.synthesize(text: text)
                    player.playData(data, preview: text)
                }
            } catch {
                // Player stays idle on error
                log.error("TTS failed: \(error.localizedDescription)")
                FileLog.log("tts: FAILED — \(error)")
            }
        }
    }
}
