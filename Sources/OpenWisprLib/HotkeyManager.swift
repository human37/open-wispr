import AppKit
import Foundation

class HotkeyManager {
    private var globalMonitor: Any?
    private let keyCode: UInt16
    private let requiredModifiers: UInt64
    private var onKeyDown: (() -> Void)?
    private var onKeyUp: (() -> Void)?
    private var modifierPressed = false

    init(keyCode: UInt16, modifiers: UInt64 = 0) {
        self.keyCode = keyCode
        self.requiredModifiers = modifiers
    }

    func start(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handleEvent(event)
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        globalMonitor = nil
    }

    private func handleEvent(_ event: NSEvent) {
        if isModifierOnlyKey(keyCode) {
            guard event.type == .flagsChanged else { return }
            guard event.keyCode == keyCode else { return }

            if modifierPressed {
                modifierPressed = false
                onKeyUp?()
            } else {
                if requiredModifiers != 0 {
                    let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
                    guard currentMods & requiredModifiers == requiredModifiers else { return }
                }
                modifierPressed = true
                onKeyDown?()
            }
        } else {
            guard event.keyCode == keyCode else { return }
            if requiredModifiers != 0 {
                let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
                guard currentMods & requiredModifiers == requiredModifiers else { return }
            }
            if event.type == .keyDown {
                guard !event.isARepeat else { return }
                onKeyDown?()
            } else if event.type == .keyUp {
                onKeyUp?()
            }
        }
    }

    private func isModifierOnlyKey(_ code: UInt16) -> Bool {
        return [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(code)
    }
}
