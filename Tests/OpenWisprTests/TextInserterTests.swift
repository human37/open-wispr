import XCTest
@testable import OpenWisprLib

final class TextInserterTests: XCTestCase {

    func testPasteKeyCodeResolvesForCurrentLayout() {
        let inserter = TextInserter()
        XCTAssertTrue(inserter.pasteKeyCode < 128, "Paste key code should be a valid virtual key code")
    }
}
