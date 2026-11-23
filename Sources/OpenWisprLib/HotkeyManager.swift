import AppKit
import Foundation

class HotkeyManager {
    typealias GlobalMonitorInstaller = (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Any?
    typealias LocalMonitorInstaller = (NSEvent.EventTypeMask, @escaping (NSEvent) -> NSEvent?) -> Any?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let keyCode: UInt16
    private let requiredModifiers: UInt64
    private let addGlobalMonitor: GlobalMonitorInstaller
    private let addLocalMonitor: LocalMonitorInstaller
    private let removeMonitor: (Any) -> Void
    private var onKeyDown: (() -> Void)?
    private var onKeyUp: (() -> Void)?
    private var onCancel: (() -> Void)?
    private var modifierPressed = false

    init(
        keyCode: UInt16,
        modifiers: UInt64 = 0,
        addGlobalMonitor: @escaping GlobalMonitorInstaller = { mask, handler in
            NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        },
        addLocalMonitor: @escaping LocalMonitorInstaller = { mask, handler in
            NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
        },
        removeMonitor: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }
    ) {
        self.keyCode = keyCode
        self.requiredModifiers = modifiers
        self.addGlobalMonitor = addGlobalMonitor
        self.addLocalMonitor = addLocalMonitor
        self.removeMonitor = removeMonitor
    }

    func start(
        onKeyDown: @escaping () -> Void,
        onKeyUp: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp
        self.onCancel = onCancel

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        globalMonitor = addGlobalMonitor(mask) { [weak self] event in
            self?.handleEvent(event)
        }
        localMonitor = addLocalMonitor(mask) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            removeMonitor(monitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleEvent(_ event: NSEvent) {
        if isModifierOnlyKey(keyCode) {
            // A modifier-only hotkey must be pressed on its own. Any other key or
            // modifier while it's held means it's being used as a modifier (Fn+arrow,
            // Fn+Delete, Fn+F-keys...), so the press is cancelled.
            if modifierPressed, event.type == .keyDown || (event.type == .flagsChanged && event.keyCode != keyCode) {
                modifierPressed = false
                onCancel?()
                return
            }

            guard event.type == .flagsChanged else { return }
            guard event.keyCode == keyCode else { return }

            let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
            let isDown = currentMods & ownFlag(keyCode) != 0

            if modifierPressed {
                guard !isDown else { return }
                modifierPressed = false
                onKeyUp?()
            } else {
                guard isDown else { return }
                if currentMods & ~(requiredModifiers | ownFlag(keyCode)) != 0 { return }
                if requiredModifiers != 0 {
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
                onKeyDown?()
            } else if event.type == .keyUp {
                onKeyUp?()
            }
        }
    }

    private func ownFlag(_ code: UInt16) -> UInt64 {
        let flags: NSEvent.ModifierFlags
        switch code {
        case 54, 55: flags = .command
        case 56, 60: flags = .shift
        case 58, 61: flags = .option
        case 59, 62: flags = .control
        case 63: flags = .function
        default: flags = []
        }
        return UInt64(flags.rawValue)
    }

    private func isModifierOnlyKey(_ code: UInt16) -> Bool {
        return [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(code)
    }
}
