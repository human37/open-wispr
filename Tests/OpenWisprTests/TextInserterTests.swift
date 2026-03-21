import XCTest
@testable import OpenWisprLib

final class TextInserterTests: XCTestCase {

    func testPasteKeyCodeIsHardcodedToVirtualV() {
        XCTAssertEqual(TextInserter.pasteKeyCode, 9, "Paste key code must be 9 (virtual 'V' position) to work across all keyboard layouts")
    }
}
