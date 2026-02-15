import Carbon
import CoreGraphics
import Foundation

class HotkeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let keyCode: UInt16
    private let requiredModifiers: UInt64
    private var onKeyDown: (() -> Void)?
    private var onKeyUp: (() -> Void)?

    init(keyCode: UInt16, modifiers: UInt64 = 0) {
        self.keyCode = keyCode
        self.requiredModifiers = modifiers
    }

    func start(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) throws {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: refcon
        ) else {
            throw HotkeyError.accessibilityNotGranted
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        if keyCode == code || isModifierOnlyKey(keyCode) {
            if isModifierOnlyKey(keyCode) {
                let flags = event.flags.rawValue
                let isPressed = (flags & modifierMaskForKey(keyCode)) != 0

                if type == .flagsChanged {
                    if isPressed {
                        onKeyDown?()
                    } else {
                        onKeyUp?()
                    }
                    return nil
                }
            } else {
                if type == .keyDown {
                    onKeyDown?()
                    return nil
                } else if type == .keyUp {
                    onKeyUp?()
                    return nil
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func isModifierOnlyKey(_ code: UInt16) -> Bool {
        return [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(code)
    }

    private func modifierMaskForKey(_ code: UInt16) -> UInt64 {
        switch code {
        case 54, 55: return UInt64(CGEventFlags.maskCommand.rawValue)
        case 56, 60: return UInt64(CGEventFlags.maskShift.rawValue)
        case 58, 61: return UInt64(CGEventFlags.maskAlternate.rawValue)
        case 59, 62: return UInt64(CGEventFlags.maskControl.rawValue)
        case 63: return UInt64(CGEventFlags.maskSecondaryFn.rawValue)
        default: return 0
        }
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passRetained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    return manager.handleEvent(type: type, event: event)
}

enum HotkeyError: LocalizedError {
    case accessibilityNotGranted

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return """
            Accessibility permission required.
            Go to System Settings → Privacy & Security → Accessibility
            and add open-wispr (or your terminal app).
            """
        }
    }
}
