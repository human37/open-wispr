import AppKit
import Foundation

enum AppBundleLaunch {
    private static let bundleMarker = ".app/Contents/MacOS/"

    static func isExecutableInsideAppBundle(_ path: String) -> Bool {
        path.contains(bundleMarker)
    }

    static func findOpenWisprAppBundle() -> URL? {
        if let env = ProcessInfo.processInfo.environment["OPEN_WISPR_APP"]?.trimmingCharacters(in: .whitespacesAndNewlines), !env.isEmpty {
            let path = (env as NSString).expandingTildeInPath
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }

        let exec = URL(fileURLWithPath: ProcessInfo.processInfo.arguments[0]).resolvingSymlinksInPath()
        var dir = exec.deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent("OpenWispr.app", isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let homeApps = home.appendingPathComponent("Applications/OpenWispr.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: homeApps.path) { return homeApps }
        let system = URL(fileURLWithPath: "/Applications/OpenWispr.app", isDirectory: true)
        if FileManager.default.fileExists(atPath: system.path) { return system }
        return nil
    }

    @discardableResult
    static func relaunchThroughAppBundleIfNeeded() -> Bool {
        let exec = ProcessInfo.processInfo.arguments[0]
        if isExecutableInsideAppBundle(exec) { return false }
        guard let appURL = findOpenWisprAppBundle() else { return false }

        fputs("Relaunching via \(appURL.path) so Microphone/Accessibility apply to OpenWispr, not Terminal.\n", stdout)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", appURL.path, "--args", "start"]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            fputs("Error: could not start OpenWispr.app: \(error.localizedDescription)\n", stderr)
            return false
        }
        if process.terminationStatus != 0 {
            fputs("Error: 'open' exited with status \(process.terminationStatus)\n", stderr)
            return false
        }
        return true
    }
}
