import AVFoundation
import Combine

@Observable
final class AudioPlayerService: NSObject {
    static let shared = AudioPlayerService()

    private(set) var state: PlayerState = .idle
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var textPreview: String = ""

    var progress: Double {
        duration > 0 ? currentTime / duration : 0
    }

    private var player: AVAudioPlayer?
    private var queue: [Data] = []
    private var queueIndex = 0
    private var timer: Timer?
    private let settings = SettingsService.shared

    override private init() {
        super.init()
    }

    func playData(_ data: Data, preview: String = "") {
        queue = [data]
        queueIndex = 0
        textPreview = String(preview.prefix(100))
        playCurrentSegment()
    }

    func playQueue(_ segments: [Data], preview: String = "") {
        guard !segments.isEmpty else { return }
        queue = segments
        queueIndex = 0
        textPreview = String(preview.prefix(100))
        playCurrentSegment()
    }

    func play() {
        guard let player else { return }
        player.play()
        state = .playing
        startTimer()
    }

    func pause() {
        player?.pause()
        state = .paused
        stopTimer()
    }

    func togglePlayPause() {
        switch state {
        case .playing: pause()
        case .paused: play()
        default: break
        }
    }

    func stop() {
        player?.stop()
        player = nil
        queue = []
        queueIndex = 0
        state = .idle
        currentTime = 0
        duration = 0
        textPreview = ""
        stopTimer()
    }

    func skipForward() {
        guard let player else { return }
        let newTime = min(player.currentTime + settings.skipInterval, player.duration)
        if newTime >= player.duration {
            advanceQueue()
        } else {
            player.currentTime = newTime
            currentTime = newTime
        }
    }

    func skipBackward() {
        guard let player else { return }
        let newTime = max(player.currentTime - settings.skipInterval, 0)
        player.currentTime = newTime
        currentTime = newTime
    }

    func seek(to fraction: Double) {
        guard let player else { return }
        let newTime = fraction * player.duration
        player.currentTime = newTime
        currentTime = newTime
    }

    // MARK: - Private

    private func playCurrentSegment() {
        guard queueIndex < queue.count else {
            stop()
            return
        }

        do {
            player = try AVAudioPlayer(data: queue[queueIndex])
            player?.delegate = self
            player?.play()
            state = .playing
            duration = player?.duration ?? 0
            currentTime = 0
            startTimer()
        } catch {
            stop()
        }
    }

    private func advanceQueue() {
        queueIndex += 1
        if queueIndex < queue.count {
            playCurrentSegment()
        } else {
            stop()
        }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioPlayerService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advanceQueue()
    }
}
