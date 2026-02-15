import AVFoundation
import ApplicationServices
import Foundation

struct Permissions {
    static func ensureAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        print("  Accessibility: waiting for permission...")
        print("  Grant access in the system dialog, then it will continue automatically.")

        while !AXIsProcessTrusted() {
            Thread.sleep(forTimeInterval: 2)
        }

        print("  Accessibility: granted")
        return true
    }

    static func ensureMicrophone() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            print("  Microphone: requesting...")
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { result in
                granted = result
                semaphore.signal()
            }
            semaphore.wait()
            if !granted {
                print("  Microphone: denied — grant in System Settings → Privacy & Security → Microphone")
            }
            return granted
        default:
            print("  Microphone: denied — grant in System Settings → Privacy & Security → Microphone")
            return false
        }
    }

    static func ensureAll() -> Bool {
        print("Checking permissions...")

        let mic = ensureMicrophone()
        if mic {
            print("  Microphone: granted")
        }

        let accessibility = ensureAccessibility()

        print("")
        return mic && accessibility
    }
}
