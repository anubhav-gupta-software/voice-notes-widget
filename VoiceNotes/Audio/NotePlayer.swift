import AVFoundation

@MainActor
@Observable
final class NotePlayer {
    private(set) var noteID: UUID?
    private(set) var isPlaying = false
    private(set) var progress: Double = 0
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var ticker: Task<Void, Never>?
    private let delegate = PlayerDelegate()

    init() {
        delegate.owner = self
    }

    func play(url: URL, noteID: UUID) {
        if self.noteID == noteID, let player {
            if player.currentTime >= max(0, player.duration - 0.05) {
                player.currentTime = 0
            }
            player.play()
            isPlaying = true
            startTicker()
            return
        }

        stop()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio)
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = delegate
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
            self.noteID = noteID
            duration = player.duration
            isPlaying = true
            startTicker()
        } catch {
            self.noteID = nil
            isPlaying = false
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        ticker?.cancel()
    }

    func toggle(url: URL, noteID: UUID) {
        if self.noteID == noteID, isPlaying {
            pause()
        } else {
            play(url: url, noteID: noteID)
        }
    }

    func seek(to fraction: Double) {
        guard let player, player.duration > 0 else { return }
        let clamped = min(1, max(0, fraction))
        player.currentTime = clamped * player.duration
        currentTime = player.currentTime
        progress = clamped
    }

    func stop() {
        ticker?.cancel()
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        currentTime = 0
        duration = 0
        noteID = nil
    }

    fileprivate func handleFinish() {
        ticker?.cancel()
        isPlaying = false
        progress = 1
        currentTime = duration
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor in
            while !Task.isCancelled, let player, isPlaying {
                currentTime = player.currentTime
                duration = player.duration
                progress = player.duration > 0 ? player.currentTime / player.duration : 0
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}

private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    weak var owner: NotePlayer?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak owner] in
            owner?.handleFinish()
        }
    }
}
