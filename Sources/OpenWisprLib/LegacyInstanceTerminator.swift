import AppKit
import Foundation

protocol RunningApplicationInstance: AnyObject {
    var processIdentifier: pid_t { get }
    var isTerminated: Bool { get }
    func terminate() -> Bool
    func forceTerminate() -> Bool
}

extension NSRunningApplication: RunningApplicationInstance {}

public struct LegacyInstanceTerminationResult: Equatable {
    public let foundCount: Int
    public let forceTerminationCount: Int
    public let remainingProcessIdentifiers: [pid_t]
}

public enum LegacyInstanceTerminator {
    public static func terminatePreviousInstances() -> LegacyInstanceTerminationResult {
        let applications: [any RunningApplicationInstance] = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.human37.open-wispr"
        )

        return terminatePreviousInstances(
            currentProcessIdentifier: ProcessInfo.processInfo.processIdentifier,
            applications: applications,
            sleep: { interval in
                RunLoop.current.run(until: Date(timeIntervalSinceNow: interval))
            }
        )
    }

    static func terminatePreviousInstances(
        currentProcessIdentifier: pid_t,
        applications: [any RunningApplicationInstance],
        gracefulPollCount: Int = 10,
        forcePollCount: Int = 10,
        pollInterval: TimeInterval = 0.05,
        sleep: (TimeInterval) -> Void
    ) -> LegacyInstanceTerminationResult {
        let candidates = applications.filter {
            $0.processIdentifier != currentProcessIdentifier && !$0.isTerminated
        }

        for application in candidates {
            _ = application.terminate()
        }

        waitForTermination(
            candidates,
            pollCount: gracefulPollCount,
            pollInterval: pollInterval,
            sleep: sleep
        )

        let forceCandidates = candidates.filter { !$0.isTerminated }
        for application in forceCandidates {
            _ = application.forceTerminate()
        }

        waitForTermination(
            forceCandidates,
            pollCount: forcePollCount,
            pollInterval: pollInterval,
            sleep: sleep
        )

        return LegacyInstanceTerminationResult(
            foundCount: candidates.count,
            forceTerminationCount: forceCandidates.count,
            remainingProcessIdentifiers: candidates
                .filter { !$0.isTerminated }
                .map(\.processIdentifier)
        )
    }

    private static func waitForTermination(
        _ applications: [any RunningApplicationInstance],
        pollCount: Int,
        pollInterval: TimeInterval,
        sleep: (TimeInterval) -> Void
    ) {
        var remainingPolls = pollCount
        while remainingPolls > 0 && applications.contains(where: { !$0.isTerminated }) {
            sleep(pollInterval)
            remainingPolls -= 1
        }
    }
}
