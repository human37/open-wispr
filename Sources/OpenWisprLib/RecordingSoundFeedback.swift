import AppKit

/// Keeps the system sounds alive while AppKit plays them asynchronously.
final class RecordingSoundFeedback {
    private let started = NSSound(named: NSSound.Name("Tink"))
    private let stopped = NSSound(named: NSSound.Name("Pop"))

    func playStarted() {
        started?.play()
    }

    func playStopped() {
        stopped?.play()
    }
}
