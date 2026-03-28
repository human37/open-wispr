import XCTest
@testable import OpenWisprLib

final class TextInserterTests: XCTestCase {

    func testPasteKeyCodeIsHardcodedToVirtualV() {
        XCTAssertEqual(TextInserter.pasteKeyCode, 9, "Paste key code must be 9 (virtual 'V' position) to work across all keyboard layouts")
    }

    func testDefaultPasteMethodIsCGEvent() {
        let inserter = TextInserter(inputMethod: nil)
        XCTAssertEqual(inserter.resolvedInputMethod, "cgevent")
    }

    func testAppleScriptPasteMethodIsRecognized() {
        let inserter = TextInserter(inputMethod: "applescript")
        XCTAssertEqual(inserter.resolvedInputMethod, "applescript")
    }

    func testUnknownPasteMethodDefaultsToCGEvent() {
        let inserter = TextInserter(inputMethod: "garbage")
        XCTAssertEqual(inserter.resolvedInputMethod, "cgevent")
    }
}
