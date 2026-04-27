import AppKit
import AVFoundation
import ApplicationServices
import CoreGraphics
import Foundation

struct Permissions {
    private static let screenCapturePendingRestartKey = "openwispr.screenCapturePendingRestart"
    private static let screenCaptureWasMissingAtLaunchKey = "openwispr.screenCaptureWasMissingAtLaunch"
    private static var screenCaptureRequestAttemptedThisLaunch = false

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

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func promptAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    enum ScreenCaptureAccess {
        case granted
        case requiresRestart
        case needsSystemSettings
    }

    static func noteLaunchPermissionState() {
        let missingAtLaunch = !CGPreflightScreenCaptureAccess()
        screenCaptureRequestAttemptedThisLaunch = false
        UserDefaults.standard.set(missingAtLaunch, forKey: screenCaptureWasMissingAtLaunchKey)
        if !missingAtLaunch {
            UserDefaults.standard.set(false, forKey: screenCapturePendingRestartKey)
        }
    }

    static func screenCaptureRestartIsPending() -> Bool {
        UserDefaults.standard.bool(forKey: screenCapturePendingRestartKey)
    }

    static func clearPendingScreenCaptureRestart() {
        screenCaptureRequestAttemptedThisLaunch = false
        UserDefaults.standard.set(false, forKey: screenCapturePendingRestartKey)
        UserDefaults.standard.set(false, forKey: screenCaptureWasMissingAtLaunchKey)
    }

    static func screenCapturePermissionWasGrantedAfterLaunch() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: screenCaptureWasMissingAtLaunchKey),
              CGPreflightScreenCaptureAccess() else {
            return false
        }

        defaults.set(true, forKey: screenCapturePendingRestartKey)
        defaults.set(false, forKey: screenCaptureWasMissingAtLaunchKey)
        return true
    }

    static func openScreenCaptureSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    static func ensureScreenCapture() -> ScreenCaptureAccess {
        if CGPreflightScreenCaptureAccess() {
            if screenCaptureRestartIsPending() {
                print("Screen Recording: granted, restart required")
                return .requiresRestart
            }
            print("Screen Recording: granted")
            clearPendingScreenCaptureRestart()
            return .granted
        }

        if screenCaptureRequestAttemptedThisLaunch {
            print("Screen Recording: already requested this launch")
            return .needsSystemSettings
        }

        screenCaptureRequestAttemptedThisLaunch = true
        print("Screen Recording: requesting...")
        if CGRequestScreenCaptureAccess() {
            UserDefaults.standard.set(true, forKey: screenCapturePendingRestartKey)
            UserDefaults.standard.set(false, forKey: screenCaptureWasMissingAtLaunchKey)
            return .requiresRestart
        }

        return .needsSystemSettings
    }
}
