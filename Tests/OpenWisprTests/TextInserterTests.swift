import XCTest
@testable import OpenWisprLib

final class TextInserterTests: XCTestCase {

    func testPasteKeyCodeIsHardcodedToVirtualV() {
        XCTAssertEqual(TextInserter.pasteKeyCode, 9, "Paste key code must be 9 (virtual 'V' position) to work across all keyboard layouts")
    }

    func testDefaultPasteMethodIsCGEvent() {
        let inserter = TextInserter(pasteMethod: nil)
        XCTAssertEqual(inserter.resolvedPasteMethod, "cgevent")
    }

    func testAppleScriptPasteMethodIsRecognized() {
        let inserter = TextInserter(pasteMethod: "applescript")
        XCTAssertEqual(inserter.resolvedPasteMethod, "applescript")
    }

    func testUnknownPasteMethodDefaultsToCGEvent() {
        let inserter = TextInserter(pasteMethod: "garbage")
        XCTAssertEqual(inserter.resolvedPasteMethod, "cgevent")
    }
}
