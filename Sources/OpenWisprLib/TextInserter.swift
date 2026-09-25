import AppKit
import Foundation
import Cocoa
import Carbon.HIToolbox

protocol TextInsertionPasteboard: AnyObject {
    var pasteboardItems: [NSPasteboardItem]? { get }
    var changeCount: Int { get }

    @discardableResult
    func clearContents() -> Int

    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool

    @discardableResult
    func writeItems(_ items: [NSPasteboardItem]) -> Bool
}

extension NSPasteboard: TextInsertionPasteboard {
    func writeItems(_ items: [NSPasteboardItem]) -> Bool {
        writeObjects(items)
    }
}

class TextInserter {
    typealias PasteboardProvider = () -> any TextInsertionPasteboard
    typealias PasteAction = (CGKeyCode) -> Void
    typealias RestoreScheduler = (_ delay: TimeInterval, _ action: @escaping () -> Void) -> Void
    typealias FocusedTextInputProvider = () -> Bool?

    enum InsertionResult: Equatable {
        case pasted
        case copiedToClipboard
    }

    static let defaultRestoreDelay: TimeInterval = 1.0

    let pasteKeyCode: CGKeyCode

    private let pasteboardProvider: PasteboardProvider
    private let pasteAction: PasteAction
    private let focusedTextInputProvider: FocusedTextInputProvider
    private let restoreDelay: TimeInterval
    private let scheduleRestore: RestoreScheduler

    convenience init() {
        let pasteKeyCode = TextInserter.resolveKeyCode(for: "v") ?? 9
        self.init(
            pasteKeyCode: pasteKeyCode,
            pasteboardProvider: { NSPasteboard.general },
            pasteAction: TextInserter.simulatePaste,
            focusedTextInputProvider: TextInserter.hasFocusedTextInput,
            scheduleRestore: { delay, action in
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    action()
                }
            }
        )
    }

    init(
        pasteKeyCode: CGKeyCode,
        pasteboardProvider: @escaping PasteboardProvider,
        pasteAction: @escaping PasteAction,
        focusedTextInputProvider: @escaping FocusedTextInputProvider = { true },
        restoreDelay: TimeInterval = TextInserter.defaultRestoreDelay,
        scheduleRestore: @escaping RestoreScheduler
    ) {
        self.pasteKeyCode = pasteKeyCode
        self.pasteboardProvider = pasteboardProvider
        self.pasteAction = pasteAction
        self.focusedTextInputProvider = focusedTextInputProvider
        self.restoreDelay = restoreDelay
        self.scheduleRestore = scheduleRestore
    }

    @discardableResult
    func insert(text: String) -> InsertionResult {
        let pasteboard = pasteboardProvider()
        // A failed accessibility query is inconclusive; preserve the existing
        // paste behavior rather than silently routing text to the clipboard.
        let shouldPaste = focusedTextInputProvider() != false
        let savedItems = shouldPaste ? savePasteboard(pasteboard) : []

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let writeChangeCount = pasteboard.changeCount

        guard shouldPaste else { return .copiedToClipboard }

        pasteAction(pasteKeyCode)

        scheduleRestore(restoreDelay) {
            // If something else has written to the pasteboard since our write
            // (user copied something, another tool wrote), do not clobber it.
            guard pasteboard.changeCount == writeChangeCount else { return }
            self.restorePasteboard(pasteboard, items: savedItems)
        }
        return .pasted
    }

    private static func hasFocusedTextInput() -> Bool? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let applicationElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedValue: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(
            applicationElement, kAXFocusedUIElementAttribute as CFString, &focusedValue
        )
        if focusResult == .noValue { return false }
        guard focusResult == .success, let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else { return nil }

        let focusedElement = focusedValue as! AXUIElement
        var roleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            focusedElement, kAXRoleAttribute as CFString, &roleValue
        ) == .success, let role = roleValue as? String else { return nil }

        var editableValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            focusedElement, kAXIsEditableAttribute as CFString, &editableValue
        ) == .success, let isEditable = editableValue as? Bool, isEditable {
            return true
        }

        if role == (kAXTextFieldRole as String)
            || role == (kAXTextAreaRole as String)
            || role == (kAXComboBoxRole as String) {
            return true
        }

        // Custom editors may use other roles. Keep pasting unless the focused
        // role is clearly not a text input.
        if role == (kAXButtonRole as String)
            || role == (kAXCheckBoxRole as String)
            || role == (kAXRadioButtonRole as String)
            || role == (kAXMenuItemRole as String)
            || role == (kAXWindowRole as String) {
            return false
        }
        return nil
    }

    private func savePasteboard(_ pasteboard: any TextInsertionPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
    }

    private func restorePasteboard(_ pasteboard: any TextInsertionPasteboard, items: [[(NSPasteboard.PasteboardType, Data)]]) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let pasteboardItems = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeItems(pasteboardItems)
    }

    private static func resolveKeyCode(for target: Character) -> CGKeyCode? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
            let rawLayoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        guard let layoutBytes = CFDataGetBytePtr(layoutData) else {
            return nil
        }

        let keyboardLayout = UnsafePointer<UCKeyboardLayout>(OpaquePointer(layoutBytes))
        let keyboardType = UInt32(LMGetKbdType())
        let wanted = String(target).lowercased()

        for keyCode in 0..<128 {
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var actualLength: Int = 0

            let status = UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                keyboardType,
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                chars.count,
                &actualLength,
                &chars
            )

            guard status == noErr else { continue }

            let produced = String(utf16CodeUnits: chars, count: actualLength).lowercased()
            if produced == wanted {
                return CGKeyCode(keyCode)
            }
        }

        return nil
    }

    private static func simulatePaste(keyCode: CGKeyCode) {
        guard let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
