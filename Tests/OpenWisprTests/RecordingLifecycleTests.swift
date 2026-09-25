import XCTest
@testable import OpenWisprLib

final class RecordingLifecycleTests: XCTestCase {
    func testHoldToTalkStartsOnceAndStopsOnKeyUp() {
        var lifecycle = RecordingLifecycle()

        XCTAssertEqual(lifecycle.keyDown(toggleMode: false), .startRecording)
        XCTAssertEqual(lifecycle.keyDown(toggleMode: false), .none)
        XCTAssertEqual(lifecycle.keyUp(toggleMode: false), .stopRecording)
        XCTAssertFalse(lifecycle.isRecording)
    }

    func testToggleModeStartsAndStopsOnKeyDown() {
        var lifecycle = RecordingLifecycle()

        XCTAssertEqual(lifecycle.keyDown(toggleMode: true), .startRecording)
        XCTAssertEqual(lifecycle.keyUp(toggleMode: true), .none)
        XCTAssertEqual(lifecycle.keyDown(toggleMode: true), .stopRecording)
        XCTAssertFalse(lifecycle.isRecording)
    }

    func testSleepWhileIdleDoesNotRequestTranscription() {
        var lifecycle = RecordingLifecycle()

        XCTAssertEqual(lifecycle.systemWillSleep(), .none)
        XCTAssertFalse(lifecycle.isRecording)
    }

    func testSleepWhileRecordingCancelsInsteadOfStopping() {
        var lifecycle = RecordingLifecycle()

        XCTAssertEqual(lifecycle.keyDown(toggleMode: false), .startRecording)
        XCTAssertEqual(lifecycle.systemWillSleep(), .cancelRecording)
        XCTAssertFalse(lifecycle.isRecording)
        XCTAssertEqual(lifecycle.keyDown(toggleMode: false), .startRecording)
        XCTAssertEqual(lifecycle.keyUp(toggleMode: false), .stopRecording)
    }

    func testWakePreparesOnlyWhenReady() {
        let lifecycle = RecordingLifecycle()

        XCTAssertEqual(lifecycle.systemDidWake(isReady: false), .none)
        XCTAssertEqual(lifecycle.systemDidWake(isReady: true), .prepareRecorder)
    }

    func testStartFailureReturnsLifecycleToIdle() {
        var lifecycle = RecordingLifecycle()

        XCTAssertEqual(lifecycle.keyDown(toggleMode: false), .startRecording)
        lifecycle.recordingStartFailed()
        XCTAssertFalse(lifecycle.isRecording)
        XCTAssertEqual(lifecycle.keyDown(toggleMode: false), .startRecording)
    }

    func testDiscardCancelledRecordingRemovesPartialFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("open-wispr-cancel-\(UUID().uuidString).wav")
        try Data("partial".utf8).write(to: url)

        RecordingCancellation.discardPartialRecording(at: url)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDiscardCancelledRecordingAllowsMissingFile() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("open-wispr-cancel-\(UUID().uuidString).wav")

        RecordingCancellation.discardPartialRecording(at: url)

        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testDiscardTrackedPartialRecordingRemovesFileBeforeClearingURL() throws {
        var trackedURL: URL? = FileManager.default.temporaryDirectory.appendingPathComponent("open-wispr-cancel-\(UUID().uuidString).wav")
        let path = try XCTUnwrap(trackedURL?.path)
        try Data("partial".utf8).write(to: XCTUnwrap(trackedURL))

        RecordingCancellation.discardTrackedPartialRecording(&trackedURL)

        XCTAssertNil(trackedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
    }
}
