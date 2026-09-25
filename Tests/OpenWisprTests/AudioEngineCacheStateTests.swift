import XCTest
@testable import OpenWisprLib

final class AudioEngineCacheStateTests: XCTestCase {
    func testUnchangedRouteCanReuseStoppedEngine() {
        let route = AudioEngineCacheState.Route(inputDeviceID: 1, outputDeviceID: 2)
        let state = AudioEngineCacheState(route: route)
        XCTAssertTrue(state.canReuse(for: route))
    }

    func testInputChangeRequiresNewEngine() {
        let state = AudioEngineCacheState(route: .init(inputDeviceID: 1, outputDeviceID: 2))
        XCTAssertFalse(state.canReuse(for: .init(inputDeviceID: 3, outputDeviceID: 2)))
    }

    func testOutputChangeRequiresNewEngine() {
        let state = AudioEngineCacheState(route: .init(inputDeviceID: 1, outputDeviceID: 2))
        XCTAssertFalse(state.canReuse(for: .init(inputDeviceID: 1, outputDeviceID: 3)))
    }

    func testDefaultInputChangeInvalidatesPreferredDeviceCache() {
        let state = AudioEngineCacheState(route: .init(inputDeviceID: 1, outputDeviceID: 2, defaultInputDeviceID: 1))
        XCTAssertFalse(state.canReuse(for: .init(inputDeviceID: 1, outputDeviceID: 2, defaultInputDeviceID: 3)))
    }

    func testFormatChangeInvalidatesUnchangedDeviceIDs() {
        let route = AudioEngineCacheState.Route(inputDeviceID: 1, outputDeviceID: 2)
        let state = AudioEngineCacheState(route: route)
        state.invalidate()
        XCTAssertFalse(state.canReuse(for: route))
    }

    func testLateNotificationCannotInvalidateReplacementEngine() {
        let route = AudioEngineCacheState.Route(inputDeviceID: 1, outputDeviceID: 2)
        let old = AudioEngineCacheState(route: route)
        let replacement = AudioEngineCacheState(route: route)
        old.invalidate()
        XCTAssertTrue(replacement.canReuse(for: route))
    }
}
