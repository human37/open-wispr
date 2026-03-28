import XCTest
@testable import OpenWisprLib

final class TextInserterTests: XCTestCase {

    func testPasteKeyCodeResolvesForCurrentLayout() {
        let inserter = TextInserter()
        XCTAssertTrue(inserter.pasteKeyCode < 128, "Paste key code should be a valid virtual key code")
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
