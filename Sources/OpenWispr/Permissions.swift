import AVFoundation
import ApplicationServices
import Foundation

struct Permissions {
    static func ensureMicrophone() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                semaphore.signal()
            }
            semaphore.wait()
        default:
            print("Microphone denied. Grant in System Settings → Privacy & Security → Microphone")
        }
    }
}
