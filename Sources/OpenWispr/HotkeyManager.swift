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
            let pressed = isModifierActive(event.modifierFlags)
            if pressed && !modifierPressed {
                modifierPressed = true
                onKeyDown?()
            } else if !pressed && modifierPressed {
                modifierPressed = false
                onKeyUp?()
            }
        } else {
            guard event.keyCode == keyCode else { return }
            if requiredModifiers != 0 {
                let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
                guard currentMods & requiredModifiers == requiredModifiers else { return }
            }
            if event.type == .keyDown {
                onKeyDown?()
            } else if event.type == .keyUp {
                onKeyUp?()
            }
        }
    }

    private func isModifierActive(_ flags: NSEvent.ModifierFlags) -> Bool {
        switch keyCode {
        case 54, 55: return flags.contains(.command)
        case 56, 60: return flags.contains(.shift)
        case 58, 61: return flags.contains(.option)
        case 59, 62: return flags.contains(.control)
        case 63: return flags.contains(.function)
        default: return false
        }
    }

    private func isModifierOnlyKey(_ code: UInt16) -> Bool {
        return [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(code)
    }
}
