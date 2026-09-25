import XCTest
@testable import OpenWisprLib

final class RecordingStoreTests: XCTestCase {
    private var testDir: URL!
    private var savedDir: URL!

    override func setUp() {
        super.setUp()
        savedDir = RecordingStore.recordingsDir
        testDir = FileManager.default.temporaryDirectory.appendingPathComponent("open-wispr-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        RecordingStore.recordingsDir = testDir
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        RecordingStore.recordingsDir = savedDir
        super.tearDown()
    }

    func testNewRecordingURLCreatesValidPath() {
        let url = RecordingStore.newRecordingURL()
        XCTAssertTrue(url.lastPathComponent.hasPrefix("recording-"))
        XCTAssertEqual(url.pathExtension, "wav")
        XCTAssertTrue(url.path.contains(testDir.path))
    }

    func testNewRecordingURLsAreUnique() {
        let url1 = RecordingStore.newRecordingURL()
        let url2 = RecordingStore.newRecordingURL()
        XCTAssertNotEqual(url1, url2)
    }

    func testTempRecordingURL() {
        let url = RecordingStore.tempRecordingURL()
        XCTAssertTrue(url.lastPathComponent.hasPrefix("open-wispr-recording-"))
        XCTAssertEqual(url.pathExtension, "wav")
    }

    func testListRecordingsEmpty() {
        let recordings = RecordingStore.listRecordings()
        XCTAssertTrue(recordings.isEmpty)
    }

    func testListRecordingsFindsFiles() throws {
        let url1 = RecordingStore.newRecordingURL()
        let url2 = RecordingStore.newRecordingURL()
        try Data("fake".utf8).write(to: url1)
        try Data("fake".utf8).write(to: url2)

        let recordings = RecordingStore.listRecordings()
        XCTAssertEqual(recordings.count, 2)
    }

    func testListRecordingsIgnoresNonRecordingFiles() throws {
        let bogus = testDir.appendingPathComponent("notes.txt")
        try Data("not a recording".utf8).write(to: bogus)

        let recordings = RecordingStore.listRecordings()
        XCTAssertTrue(recordings.isEmpty)
    }

    func testListRecordingsSortedNewestFirst() throws {
        let older = testDir.appendingPathComponent("recording-2025-01-01-120000-AAAAAAAA.wav")
        let newer = testDir.appendingPathComponent("recording-2025-06-15-150000-BBBBBBBB.wav")
        try Data("fake".utf8).write(to: older)
        try Data("fake".utf8).write(to: newer)

        let recordings = RecordingStore.listRecordings()
        XCTAssertEqual(recordings.count, 2)
        XCTAssertTrue(recordings[0].date > recordings[1].date)
    }

    func testPruneRemovesOldest() throws {
        let urls = [
            testDir.appendingPathComponent("recording-2025-01-01-100000-AAAAAAAA.wav"),
            testDir.appendingPathComponent("recording-2025-01-01-110000-BBBBBBBB.wav"),
            testDir.appendingPathComponent("recording-2025-01-01-120000-CCCCCCCC.wav"),
        ]
        for url in urls {
            try Data("fake".utf8).write(to: url)
        }

        RecordingStore.prune(maxCount: 2)
        let remaining = RecordingStore.listRecordings()
        XCTAssertEqual(remaining.count, 2)
        XCTAssertTrue(remaining.allSatisfy { $0.url.lastPathComponent != "recording-2025-01-01-100000-AAAAAAAA.wav" })
    }

    func testPruneDoesNothingWhenUnderLimit() throws {
        let url = RecordingStore.newRecordingURL()
        try Data("fake".utf8).write(to: url)

        RecordingStore.prune(maxCount: 5)
        XCTAssertEqual(RecordingStore.listRecordings().count, 1)
    }

    func testDeleteAllRecordings() throws {
        for _ in 0..<3 {
            let url = RecordingStore.newRecordingURL()
            try Data("fake".utf8).write(to: url)
        }
        XCTAssertEqual(RecordingStore.listRecordings().count, 3)

        RecordingStore.deleteAllRecordings()
        XCTAssertEqual(RecordingStore.listRecordings().count, 0)
    }
}
