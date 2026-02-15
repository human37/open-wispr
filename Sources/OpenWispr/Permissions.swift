import AVFoundation
import ApplicationServices
import Foundation

struct Permissions {
    static func ensureAccessibility() -> Bool {
        if AXIsProcessTrusted() { return true }

        print("  Accessibility: not granted")
        print("  Open System Settings → Privacy & Security → Accessibility")
        print("  Enable 'OpenWispr', then it will start automatically.")
        print("")

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
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { result in
                granted = result
                semaphore.signal()
            }
            semaphore.wait()
            return granted
        default:
            return false
        }
    }

    static func ensureAll() {
        let mic = ensureMicrophone()
        print("  Microphone: \(mic ? "granted" : "denied")")
        let _ = ensureAccessibility()
    }
}
