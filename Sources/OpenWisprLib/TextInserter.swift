import AppKit
import Foundation
import Cocoa

class TextInserter {
    let resolvedInputMethod: String

    init(inputMethod: String? = nil) {
        let method = (inputMethod ?? "cgevent").lowercased()
        self.resolvedInputMethod = ["cgevent", "applescript"].contains(method) ? method : "cgevent"
    }

    func insert(text: String) {
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let usedAppleScript: Bool
        if resolvedInputMethod == "applescript" {
            usedAppleScript = true
            simulatePasteWithAppleScript()
        } else {
            usedAppleScript = false
            simulatePasteWithCGEvent()
        }

        let restoreDelay: Double = usedAppleScript ? 0.5 : 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelay) {
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

    static let pasteKeyCode: CGKeyCode = 9

    private func simulatePasteWithCGEvent() {
        guard let source = CGEventSource(stateID: .hidSystemState),
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Self.pasteKeyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Self.pasteKeyCode, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func simulatePasteWithAppleScript() {
        let script = NSAppleScript(source: """
            tell application "System Events"
                keystroke "v" using command down
            end tell
            """)
        var error: NSDictionary?
        script?.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript paste error: \(error)")
        }
    }
}
