import AppKit
import AVFoundation
import ApplicationServices
import Foundation

struct Permissions {
    static func ensureMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("Microphone: granted")
        case .notDetermined:
            print("Microphone: requesting...")
            let semaphore = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                print("Microphone: \(granted ? "granted" : "denied")")
                semaphore.signal()
            }
            semaphore.wait()
        default:
            print("Microphone: denied — grant in System Settings → Privacy & Security → Microphone")
        }
    }

    static func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func resetAccessibility() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "com.human37.open-wispr"]
        try? process.run()
        process.waitUntilExit()
    }

    static func didUpgrade() -> Bool {
        let configDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/open-wispr")
        let versionFile = configDir.appendingPathComponent(".last-version")
        let current = OpenWispr.version
        let raw = (try? String(contentsOf: versionFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let previous = raw.isEmpty ? nil : raw

        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

        if previous == nil {
            try? current.write(to: versionFile, atomically: true, encoding: .utf8)
            return false
        }
        if previous == current {
            return false
        }
        try? current.write(to: versionFile, atomically: true, encoding: .utf8)
        return true
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
