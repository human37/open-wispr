import AppKit
import Foundation
import Cocoa
import Carbon.HIToolbox

class TextInserter {
    let pasteKeyCode: CGKeyCode

    init() {
        self.pasteKeyCode = TextInserter.resolveKeyCode(for: "v") ?? 9
    }

    func insert(text: String) {
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulatePaste()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.restorePasteboard(pasteboard, items: savedItems)
        }
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> [[(NSPasteboard.PasteboardType, Data)]] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            }
        }
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, items: [[(NSPasteboard.PasteboardType, Data)]]) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let pasteboardItems = items.map { entries -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entries {
                item.setData(data, forType: type)
            }
            return item
        }
        pasteboard.writeObjects(pasteboardItems)
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

    private func simulatePaste() {
        let keyCode = pasteKeyCode

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
