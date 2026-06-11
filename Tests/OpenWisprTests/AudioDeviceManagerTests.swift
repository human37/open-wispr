import XCTest
@testable import OpenWisprLib

final class AudioDeviceManagerTests: XCTestCase {

    func testResolveWithoutUIDFallsBackToLegacyID() {
        XCTAssertEqual(
            AudioDeviceManager.resolveConfiguredDeviceID(uid: nil, legacyID: 42),
            42
        )
    }

    func testResolveWithoutUIDAndWithoutLegacyIDReturnsNil() {
        XCTAssertNil(AudioDeviceManager.resolveConfiguredDeviceID(uid: nil, legacyID: nil))
    }

    func testResolveWithUnknownUIDReturnsNilInsteadOfStaleID() {
        // The stored numeric ID must not be trusted when the UID it was
        // saved with no longer matches any present device.
        XCTAssertNil(
            AudioDeviceManager.resolveConfiguredDeviceID(
                uid: "OpenWisprTests:NoSuchDevice:UID",
                legacyID: 42
            )
        )
    }
}
