import AppKit
import XCTest
@testable import OpenWisprLib

final class TextInserterTests: XCTestCase {

    func testPasteKeyCodeResolvesForCurrentLayout() {
        let inserter = TextInserter()
        XCTAssertTrue(inserter.pasteKeyCode < 128, "Paste key code should be a valid virtual key code")
    }

    func testInsertWritesTranscriptionBeforePastingAndSchedulesRestore() {
        var events: [String] = []
        let pasteboard = FakePasteboard(string: "old clipboard") { events.append($0) }
        let scheduler = CapturingScheduler { events.append("schedule") }
        let inserter = makeInserter(pasteboard: pasteboard, scheduler: scheduler) { _ in
            events.append("paste:\(pasteboard.string(forType: .string) ?? "")")
        }

        inserter.insert(text: "new transcription")

        XCTAssertEqual(events, [
            "clear",
            "set:new transcription",
            "paste:new transcription",
            "schedule",
        ])
        XCTAssertEqual(pasteboard.string(forType: .string), "new transcription")
        guard let scheduledAction = scheduler.onlyScheduledAction() else { return }
        XCTAssertEqual(scheduledAction.delay, TextInserter.defaultRestoreDelay, accuracy: 0.001)
    }

    func testInsertUsesSaferDefaultRestoreDelay() {
        let pasteboard = FakePasteboard(string: "old clipboard")
        let scheduler = CapturingScheduler()
        let inserter = makeInserter(pasteboard: pasteboard, scheduler: scheduler)

        inserter.insert(text: "new transcription")

        XCTAssertEqual(TextInserter.defaultRestoreDelay, 1.0, accuracy: 0.001)
        guard let scheduledAction = scheduler.onlyScheduledAction() else { return }
        XCTAssertEqual(scheduledAction.delay, 1.0, accuracy: 0.001)
        XCTAssertEqual(pasteboard.string(forType: .string), "new transcription")
    }

    func testScheduledRestoreRestoresOriginalClipboardWhenUnchanged() {
        let pasteboard = FakePasteboard(string: "old clipboard")
        let scheduler = CapturingScheduler()
        let inserter = makeInserter(pasteboard: pasteboard, scheduler: scheduler)

        inserter.insert(text: "new transcription")
        scheduler.runOnlyScheduledAction()

        XCTAssertEqual(pasteboard.string(forType: .string), "old clipboard")
    }

    func testScheduledRestoreSkipsRestoreWhenPasteboardChanged() {
        let pasteboard = FakePasteboard(string: "old clipboard")
        let scheduler = CapturingScheduler()
        let inserter = makeInserter(pasteboard: pasteboard, scheduler: scheduler)

        inserter.insert(text: "new transcription")
        pasteboard.clearContents()
        pasteboard.setString("newer clipboard", forType: .string)
        scheduler.runOnlyScheduledAction()

        XCTAssertEqual(pasteboard.string(forType: .string), "newer clipboard")
        XCTAssertFalse(pasteboard.events.contains("writeItems"))
    }

    private func makeInserter(
        pasteboard: FakePasteboard,
        scheduler: CapturingScheduler,
        pasteAction: @escaping (CGKeyCode) -> Void = { _ in }
    ) -> TextInserter {
        TextInserter(
            pasteKeyCode: 9,
            pasteboardProvider: { pasteboard },
            pasteAction: pasteAction,
            scheduleRestore: { delay, action in
                scheduler.schedule(delay: delay, action: action)
            }
        )
    }
}

private final class FakePasteboard: TextInsertionPasteboard {
    private(set) var pasteboardItems: [NSPasteboardItem]?
    private(set) var changeCount = 0
    private(set) var events: [String] = []

    private let onEvent: (String) -> Void

    init(string: String? = nil, onEvent: @escaping (String) -> Void = { _ in }) {
        self.onEvent = onEvent

        if let string {
            let item = NSPasteboardItem()
            item.setString(string, forType: .string)
            pasteboardItems = [item]
        }
    }

    @discardableResult
    func clearContents() -> Int {
        pasteboardItems = []
        return recordChange("clear")
    }

    @discardableResult
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool {
        let item = NSPasteboardItem()
        item.setString(string, forType: dataType)
        pasteboardItems = [item]
        _ = recordChange("set:\(string)")
        return true
    }

    @discardableResult
    func writeItems(_ items: [NSPasteboardItem]) -> Bool {
        pasteboardItems = items
        _ = recordChange("writeItems")
        return true
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        pasteboardItems?.first?.string(forType: dataType)
    }

    private func recordChange(_ event: String) -> Int {
        changeCount += 1
        events.append(event)
        onEvent(event)
        return changeCount
    }
}

private final class CapturingScheduler {
    struct ScheduledAction {
        let delay: TimeInterval
        let action: () -> Void
    }

    private(set) var scheduledActions: [ScheduledAction] = []
    private let onSchedule: () -> Void

    init(onSchedule: @escaping () -> Void = {}) {
        self.onSchedule = onSchedule
    }

    func schedule(delay: TimeInterval, action: @escaping () -> Void) {
        scheduledActions.append(ScheduledAction(delay: delay, action: action))
        onSchedule()
    }

    func onlyScheduledAction(file: StaticString = #filePath, line: UInt = #line) -> ScheduledAction? {
        XCTAssertEqual(scheduledActions.count, 1, file: file, line: line)
        guard scheduledActions.count == 1 else { return nil }
        return scheduledActions[0]
    }

    func runOnlyScheduledAction(file: StaticString = #filePath, line: UInt = #line) {
        onlyScheduledAction(file: file, line: line)?.action()
    }
}
