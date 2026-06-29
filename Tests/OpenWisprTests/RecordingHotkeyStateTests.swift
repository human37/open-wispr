import XCTest
@testable import OpenWisprLib

final class RecordingHotkeyStateTests: XCTestCase {
    private let holdBinding = HotkeyBinding(keyCode: 63, modifierFlags: 0)
    private let toggleBinding = HotkeyBinding(keyCode: 61, modifierFlags: 0)
    private let otherToggleBinding = HotkeyBinding(keyCode: 96, modifierFlags: 0)

    func testHoldKeyStartsAndStopsOnSameKeyRelease() {
        var state = RecordingHotkeyState()

        XCTAssertEqual(state.keyDown(binding: holdBinding, mode: .hold), .start)
        XCTAssertTrue(state.isRecording)
        XCTAssertEqual(state.keyUp(binding: holdBinding, mode: .hold), .stop)
        XCTAssertFalse(state.isRecording)
    }

    func testDifferentHoldKeyReleaseDoesNotStopActiveRecording() {
        var state = RecordingHotkeyState()

        XCTAssertEqual(state.keyDown(binding: holdBinding, mode: .hold), .start)
        XCTAssertEqual(state.keyUp(binding: toggleBinding, mode: .hold), .none)
        XCTAssertTrue(state.isRecording)
        XCTAssertEqual(state.keyUp(binding: holdBinding, mode: .hold), .stop)
    }

    func testHoldKeyReleaseDoesNotStopToggleRecording() {
        var state = RecordingHotkeyState()

        XCTAssertEqual(state.keyDown(binding: toggleBinding, mode: .toggle), .start)
        XCTAssertEqual(state.keyDown(binding: holdBinding, mode: .hold), .none)
        XCTAssertEqual(state.keyUp(binding: holdBinding, mode: .hold), .none)
        XCTAssertTrue(state.isRecording)
        XCTAssertEqual(state.keyDown(binding: toggleBinding, mode: .toggle), .stop)
        XCTAssertFalse(state.isRecording)
    }

    func testToggleKeyDoesNotStopHoldRecording() {
        var state = RecordingHotkeyState()

        XCTAssertEqual(state.keyDown(binding: holdBinding, mode: .hold), .start)
        XCTAssertEqual(state.keyDown(binding: toggleBinding, mode: .toggle), .none)
        XCTAssertTrue(state.isRecording)
        XCTAssertEqual(state.keyUp(binding: holdBinding, mode: .hold), .stop)
        XCTAssertFalse(state.isRecording)
    }

    func testAnyToggleKeyStopsToggleRecording() {
        var state = RecordingHotkeyState()

        XCTAssertEqual(state.keyDown(binding: toggleBinding, mode: .toggle), .start)
        XCTAssertEqual(state.keyDown(binding: otherToggleBinding, mode: .toggle), .stop)
        XCTAssertFalse(state.isRecording)
    }
}
