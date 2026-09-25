import XCTest
@testable import OpenWisprLib

final class LegacyInstanceTerminatorTests: XCTestCase {
    func testCurrentAndTerminatedApplicationsAreIgnored() {
        let current = RunningApplicationStub(processIdentifier: 10)
        let terminated = RunningApplicationStub(processIdentifier: 11, isTerminated: true)

        let result = terminate(current: 10, applications: [current, terminated])

        XCTAssertEqual(result.foundCount, 0)
        XCTAssertEqual(current.terminateCallCount, 0)
        XCTAssertEqual(terminated.terminateCallCount, 0)
    }

    func testGracefullyTerminatedApplicationIsNotForced() {
        let application = RunningApplicationStub(
            processIdentifier: 11,
            terminateHandler: { $0.isTerminated = true }
        )

        let result = terminate(current: 10, applications: [application])

        XCTAssertEqual(result.foundCount, 1)
        XCTAssertEqual(result.forceTerminationCount, 0)
        XCTAssertEqual(application.terminateCallCount, 1)
        XCTAssertEqual(application.forceTerminateCallCount, 0)
        XCTAssertTrue(result.remainingProcessIdentifiers.isEmpty)
    }

    func testApplicationThatExitsDuringGracePeriodIsNotForced() {
        let application = RunningApplicationStub(processIdentifier: 11)

        let result = LegacyInstanceTerminator.terminatePreviousInstances(
            currentProcessIdentifier: 10,
            applications: [application],
            gracefulPollCount: 2,
            forcePollCount: 1,
            pollInterval: 0,
            sleep: { _ in application.isTerminated = true }
        )

        XCTAssertEqual(application.forceTerminateCallCount, 0)
        XCTAssertTrue(result.remainingProcessIdentifiers.isEmpty)
    }

    func testUnresponsiveApplicationIsForced() {
        let application = RunningApplicationStub(
            processIdentifier: 11,
            forceTerminateHandler: { $0.isTerminated = true }
        )

        let result = terminate(current: 10, applications: [application])

        XCTAssertEqual(result.forceTerminationCount, 1)
        XCTAssertEqual(application.forceTerminateCallCount, 1)
        XCTAssertTrue(result.remainingProcessIdentifiers.isEmpty)
    }

    func testFailedForceTerminationReportsRemainingProcess() {
        let application = RunningApplicationStub(processIdentifier: 11)

        let result = terminate(current: 10, applications: [application])

        XCTAssertEqual(result.remainingProcessIdentifiers, [11])
    }

    func testMultipleApplicationsUseSharedPollLimits() {
        let first = RunningApplicationStub(processIdentifier: 11)
        let second = RunningApplicationStub(processIdentifier: 12)
        var sleepCount = 0

        let result = LegacyInstanceTerminator.terminatePreviousInstances(
            currentProcessIdentifier: 10,
            applications: [first, second],
            gracefulPollCount: 2,
            forcePollCount: 3,
            pollInterval: 0,
            sleep: { _ in sleepCount += 1 }
        )

        XCTAssertEqual(result.foundCount, 2)
        XCTAssertEqual(sleepCount, 5)
    }

    private func terminate(
        current: pid_t,
        applications: [any RunningApplicationInstance]
    ) -> LegacyInstanceTerminationResult {
        LegacyInstanceTerminator.terminatePreviousInstances(
            currentProcessIdentifier: current,
            applications: applications,
            gracefulPollCount: 1,
            forcePollCount: 1,
            pollInterval: 0,
            sleep: { _ in }
        )
    }
}

private final class RunningApplicationStub: RunningApplicationInstance {
    let processIdentifier: pid_t
    var isTerminated: Bool
    var terminateCallCount = 0
    var forceTerminateCallCount = 0
    private let terminateHandler: ((RunningApplicationStub) -> Void)?
    private let forceTerminateHandler: ((RunningApplicationStub) -> Void)?

    init(
        processIdentifier: pid_t,
        isTerminated: Bool = false,
        terminateHandler: ((RunningApplicationStub) -> Void)? = nil,
        forceTerminateHandler: ((RunningApplicationStub) -> Void)? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.isTerminated = isTerminated
        self.terminateHandler = terminateHandler
        self.forceTerminateHandler = forceTerminateHandler
    }

    func terminate() -> Bool {
        terminateCallCount += 1
        terminateHandler?(self)
        return terminateHandler != nil
    }

    func forceTerminate() -> Bool {
        forceTerminateCallCount += 1
        forceTerminateHandler?(self)
        return forceTerminateHandler != nil
    }
}
