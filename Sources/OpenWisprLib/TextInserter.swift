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

    static let defaultRestoreDelay: TimeInterval = 1.0

    let pasteKeyCode: CGKeyCode

    private let pasteboardProvider: PasteboardProvider
    private let pasteAction: PasteAction
    private let restoreDelay: TimeInterval
    private let scheduleRestore: RestoreScheduler

    convenience init() {
        let pasteKeyCode = TextInserter.resolveKeyCode(for: "v") ?? 9
        self.init(
            pasteKeyCode: pasteKeyCode,
            pasteboardProvider: { NSPasteboard.general },
            pasteAction: TextInserter.simulatePaste,
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
        restoreDelay: TimeInterval = TextInserter.defaultRestoreDelay,
        scheduleRestore: @escaping RestoreScheduler
    ) {
        self.pasteKeyCode = pasteKeyCode
        self.pasteboardProvider = pasteboardProvider
        self.pasteAction = pasteAction
        self.restoreDelay = restoreDelay
        self.scheduleRestore = scheduleRestore
    }

    func insert(text: String) {
        let pasteboard = pasteboardProvider()
        let savedItems = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let writeChangeCount = pasteboard.changeCount

        pasteAction(pasteKeyCode)

        scheduleRestore(restoreDelay) {
            // If something else has written to the pasteboard since our write
            // (user copied something, another tool wrote), do not clobber it.
            guard pasteboard.changeCount == writeChangeCount else { return }
            self.restorePasteboard(pasteboard, items: savedItems)
        }
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
