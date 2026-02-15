import AVFoundation
import ApplicationServices
import Foundation

struct Permissions {
    static func ensureAccessibility() -> Bool {
        let trusted = AXIsProcessTrusted()
        if trusted { return true }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        let prompted = AXIsProcessTrustedWithOptions(options)

        if !prompted {
            print("Accessibility permission required.")
            print("A system dialog should have appeared — grant access, then restart open-wispr.")
            print("")
            print("If no dialog appeared, add open-wispr manually:")
            print("  System Settings → Privacy & Security → Accessibility")
        }

        return prompted
    }

    static func ensureMicrophone() -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            print("Requesting microphone access...")
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { result in
                granted = result
                semaphore.signal()
            }
            semaphore.wait()
            if !granted {
                print("Microphone access denied. Grant it in:")
                print("  System Settings → Privacy & Security → Microphone")
            }
            return granted
        default:
            print("Microphone access denied. Grant it in:")
            print("  System Settings → Privacy & Security → Microphone")
            return false
        }
    }

    static func ensureAll() -> Bool {
        print("Checking permissions...")

        let mic = ensureMicrophone()
        if mic {
            print("  Microphone: granted")
        } else {
            print("  Microphone: DENIED")
        }

        let accessibility = ensureAccessibility()
        if accessibility {
            print("  Accessibility: granted")
        } else {
            print("  Accessibility: DENIED — grant access and restart open-wispr")
        }

        print("")
        return mic && accessibility
    }
}
