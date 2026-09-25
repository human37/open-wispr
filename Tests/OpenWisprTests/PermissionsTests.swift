import XCTest
@testable import OpenWisprLib

final class PermissionsTests: XCTestCase {
    func testUpgradeDetectionDoesNotAdvanceVersionBeforeRecovery() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let versionFile = dir.appendingPathComponent(".last-version")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "0.42.0".write(to: versionFile, atomically: true, encoding: .utf8)

        XCTAssertTrue(Permissions.didUpgrade(versionFile: versionFile, currentVersion: "0.43.0"))
        XCTAssertEqual(try String(contentsOf: versionFile, encoding: .utf8), "0.42.0")

        try Permissions.recordCurrentVersion(to: versionFile, version: "0.43.0")
        XCTAssertFalse(Permissions.didUpgrade(versionFile: versionFile, currentVersion: "0.43.0"))
    }

    func testUpgradeWithMissingTrustResetsStaleEntry() {
        XCTAssertTrue(Permissions.shouldResetAccessibility(afterUpgrade: true, isTrusted: false))
    }

    func testUpgradeWithWorkingTrustPreservesGrant() {
        XCTAssertFalse(Permissions.shouldResetAccessibility(afterUpgrade: true, isTrusted: true))
    }

    func testReinstallOfSameVersionDoesNotResetTrust() {
        XCTAssertFalse(Permissions.shouldResetAccessibility(afterUpgrade: false, isTrusted: false))
    }
}
