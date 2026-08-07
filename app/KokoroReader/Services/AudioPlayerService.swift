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

    /// Bumped on every user stop or new playback. Producers streaming chunks in
    /// pass the generation they started with; a mismatch means the user moved on
    /// and their remaining chunks are rejected.
    private(set) var generation = 0

    /// Fired on playback lifecycle transitions — lets the app auto-show/hide
    /// the floating toolbar without the player knowing about windows.
    var onPlaybackStarted: (() -> Void)?
    var onPlaybackEnded: (() -> Void)?

    /// The speed the current audio was synthesized at. Live speed changes are
    /// applied as an AVAudioPlayer rate relative to this.
    var synthesisSpeed: Double = 1.0

    override private init() {
        super.init()
    }

    func playData(_ data: Data, preview: String = "") {
        generation += 1
        queue = [data]
        queueIndex = 0
        textPreview = String(preview.prefix(100))
        playCurrentSegment()
        onPlaybackStarted?()
    }

    func playQueue(_ segments: [Data], preview: String = "") {
        guard !segments.isEmpty else { return }
        generation += 1
        queue = segments
        queueIndex = 0
        textPreview = String(preview.prefix(100))
        playCurrentSegment()
        onPlaybackStarted?()
    }

    /// Append a segment to the live queue. Returns false if playback has been
    /// stopped/replaced since the producer started (drop remaining chunks).
    @discardableResult
    func appendToQueue(_ data: Data, generation producerGeneration: Int) -> Bool {
        guard producerGeneration == generation else { return false }
        if player == nil {
            // Queue drained before this chunk arrived — resume playback
            queue = [data]
            queueIndex = 0
            playCurrentSegment()
            onPlaybackStarted?()
        } else {
            queue.append(data)
        }
        return true
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
        generation += 1  // reject any in-flight streaming producers
        reset()
    }

    /// Natural end of the queue — keeps the generation so a streaming producer
    /// can still resume playback with its next chunk.
    private func finish() {
        reset()
    }

    private func reset() {
        player?.stop()
        player = nil
        queue = []
        queueIndex = 0
        state = .idle
        currentTime = 0
        duration = 0
        textPreview = ""
        stopTimer()
        onPlaybackEnded?()
    }

    /// Apply the current speed setting to in-flight audio, relative to the
    /// speed it was synthesized at. AVAudioPlayer supports 0.5–2.0x.
    func refreshRate() {
        guard let player else { return }
        let ratio = settings.speed / max(synthesisSpeed, 0.01)
        player.rate = Float(min(2.0, max(0.5, ratio)))
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
            finish()
            return
        }

        do {
            player = try AVAudioPlayer(data: queue[queueIndex])
            player?.delegate = self
            player?.enableRate = true
            refreshRate()
            player?.play()
            state = .playing
            duration = player?.duration ?? 0
            currentTime = 0
            startTimer()
        } catch {
            FileLog.log("player: failed to decode audio segment — \(error)")
            stop()
        }
    }

    private func advanceQueue() {
        queueIndex += 1
        if queueIndex < queue.count {
            playCurrentSegment()
        } else {
            finish()
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
