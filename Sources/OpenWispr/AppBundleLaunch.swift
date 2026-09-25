import AppKit
import Darwin
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

        let executableURL = appURL.appendingPathComponent("Contents/MacOS/open-wispr")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            fputs("Error: app bundle executable not found at \(executableURL.path)\n", stderr)
            return false
        }

        fputs("Relaunching via \(appURL.path) so Microphone/Accessibility apply to OpenWispr, not Terminal.\n", stdout)

        let execError = executableURL.path.withCString { executable in
            "start".withCString { start in
                var arguments: [UnsafeMutablePointer<CChar>?] = [
                    UnsafeMutablePointer(mutating: executable),
                    UnsafeMutablePointer(mutating: start),
                    nil,
                ]
                _ = arguments.withUnsafeMutableBufferPointer { buffer in
                    Darwin.execv(executable, buffer.baseAddress)
                }
                return errno
            }
        }

        let message = String(cString: strerror(execError))
        fputs("Error: could not start OpenWispr.app: \(message)\n", stderr)
        return false
    }
}
