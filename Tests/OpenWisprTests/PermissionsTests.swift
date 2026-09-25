import XCTest
@testable import OpenWisprLib

final class PermissionsTests: XCTestCase {
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
