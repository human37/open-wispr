import XCTest
@testable import OpenWisprLib

final class TranscriptLogStoreTests: XCTestCase {
    private var testDir: URL!
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    override func setUp() {
        super.setUp()
        testDir = FileManager.default.temporaryDirectory.appendingPathComponent("open-wispr-transcript-test-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }

    func testValidatedDirectoryRejectsMissingPath() {
        let missingPath = testDir.appendingPathComponent("missing").path
        XCTAssertThrowsError(try TranscriptLogStore.validatedDirectory(path: missingPath))
    }

    func testStartSessionCreatesTimestampedMarkdownFile() throws {
        let fixedDate = calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2025,
            month: 1,
            day: 10,
            hour: 10,
            minute: 40,
            second: 0
        ))!
        let store = TranscriptLogStore(directory: testDir, now: { fixedDate })

        let session = try store.startSession(model: "base.en", language: "en")

        let expectedName = "meeting-\(TranscriptLogStore.sessionDateFormatter.string(from: fixedDate)).md"
        XCTAssertEqual(session.fileURL.lastPathComponent, expectedName)
        XCTAssertTrue(FileManager.default.fileExists(atPath: session.fileURL.path))
    }

    func testAppendWritesTimestampedLinesInOrder() throws {
        let startDate = calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2025,
            month: 1,
            day: 10,
            hour: 10,
            minute: 40,
            second: 0
        ))!
        let secondDate = startDate.addingTimeInterval(35)
        let store = TranscriptLogStore(directory: testDir, now: { startDate })
        let session = try store.startSession(model: "base.en", language: "en")

        try session.append(text: "first line", at: startDate)
        try session.append(text: "second line", at: secondDate)
        try session.finish(at: secondDate)

        let contents = try String(contentsOf: session.fileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("\(TranscriptLogStore.linePrefix(for: startDate)) first line"))
        XCTAssertTrue(contents.contains("\(TranscriptLogStore.linePrefix(for: secondDate)) second line"))
        XCTAssertTrue(contents.contains("- Ended:"))
    }

    func testAppendSkipsBlankText() throws {
        let startDate = calendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2025,
            month: 1,
            day: 10,
            hour: 10,
            minute: 40,
            second: 0
        ))!
        let store = TranscriptLogStore(directory: testDir, now: { startDate })
        let session = try store.startSession(model: "base.en", language: "en")

        try session.append(text: "   ", at: startDate)

        let contents = try String(contentsOf: session.fileURL, encoding: .utf8)
        XCTAssertFalse(contents.contains("[]"))
        XCTAssertFalse(contents.contains("   "))
    }
}
