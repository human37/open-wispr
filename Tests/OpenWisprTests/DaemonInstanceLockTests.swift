import XCTest
@testable import OpenWisprLib

final class DaemonInstanceLockTests: XCTestCase {
    private var testDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-wispr-instance-lock-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: testDirectory)
        try super.tearDownWithError()
    }

    func testOnlyOneLockCanBeHeldAtATime() throws {
        let lockURL = testDirectory.appendingPathComponent("nested/daemon.lock")
        let firstLock = try XCTUnwrap(DaemonInstanceLock.acquire(at: lockURL))

        let secondLock = try withExtendedLifetime(firstLock) {
            try DaemonInstanceLock.acquire(at: lockURL)
        }

        XCTAssertNil(secondLock)
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockURL.path))
    }

    func testLockCanBeAcquiredAfterRelease() throws {
        let lockURL = testDirectory.appendingPathComponent("daemon.lock")
        var firstLock: DaemonInstanceLock? = try XCTUnwrap(DaemonInstanceLock.acquire(at: lockURL))

        XCTAssertNotNil(firstLock)
        firstLock = nil

        XCTAssertNotNil(try DaemonInstanceLock.acquire(at: lockURL))
    }

    func testChildProcessDoesNotRetainLock() throws {
        let lockURL = testDirectory.appendingPathComponent("daemon.lock")
        var firstLock: DaemonInstanceLock? = try XCTUnwrap(DaemonInstanceLock.acquire(at: lockURL))
        XCTAssertNotNil(firstLock)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["10"]
        try child.run()
        defer {
            if child.isRunning {
                child.terminate()
            }
            child.waitUntilExit()
        }

        firstLock = nil

        XCTAssertNotNil(try DaemonInstanceLock.acquire(at: lockURL))
    }
}
