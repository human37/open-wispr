import Foundation

struct RecordingLifecycle {
    enum Action: Equatable {
        case none
        case startRecording
        case stopRecording
        case cancelRecording
        case prepareRecorder
    }

    private(set) var isRecording = false

    mutating func keyDown(toggleMode: Bool) -> Action {
        if toggleMode {
            if isRecording {
                isRecording = false
                return .stopRecording
            }
            isRecording = true
            return .startRecording
        }

        guard !isRecording else { return .none }
        isRecording = true
        return .startRecording
    }

    mutating func keyUp(toggleMode: Bool) -> Action {
        guard !toggleMode, isRecording else { return .none }
        isRecording = false
        return .stopRecording
    }

    mutating func systemWillSleep() -> Action {
        guard isRecording else { return .none }
        isRecording = false
        return .cancelRecording
    }

    func systemDidWake(isReady: Bool) -> Action {
        isReady ? .prepareRecorder : .none
    }

    mutating func recordingStartFailed() {
        isRecording = false
    }
}

enum RecordingCancellation {
    static func discardPartialRecording(at url: URL?, fileManager: FileManager = .default) {
        guard let url else { return }
        try? fileManager.removeItem(at: url)
    }

    static func discardTrackedPartialRecording(_ url: inout URL?, fileManager: FileManager = .default) {
        discardPartialRecording(at: url, fileManager: fileManager)
        url = nil
    }
}
