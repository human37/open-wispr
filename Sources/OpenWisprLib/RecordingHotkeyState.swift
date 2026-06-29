enum RecordingHotkeyAction: Equatable {
    case none
    case start
    case stop
}

struct RecordingHotkeyState {
    private(set) var activeBinding: HotkeyBinding?
    private(set) var activeMode: HotkeyMode?

    var isRecording: Bool {
        activeBinding != nil
    }

    mutating func keyDown(binding: HotkeyBinding, mode: HotkeyMode) -> RecordingHotkeyAction {
        if mode == .toggle {
            if activeMode == .toggle {
                reset()
                return .stop
            }

            guard activeBinding == nil else { return .none }
            start(binding: binding, mode: mode)
            return .start
        }

        guard activeBinding == nil else { return .none }
        start(binding: binding, mode: mode)
        return .start
    }

    mutating func keyUp(binding: HotkeyBinding, mode: HotkeyMode) -> RecordingHotkeyAction {
        guard mode == .hold else { return .none }
        guard activeMode == .hold, activeBinding == binding else { return .none }

        reset()
        return .stop
    }

    mutating func reset() {
        activeBinding = nil
        activeMode = nil
    }

    private mutating func start(binding: HotkeyBinding, mode: HotkeyMode) {
        activeBinding = binding
        activeMode = mode
    }
}
