import Foundation

final class AudioEngineCacheState {
    struct Route: Equatable {
        let inputDeviceID: UInt32
        let outputDeviceID: UInt32
        let defaultInputDeviceID: UInt32

        init(inputDeviceID: UInt32, outputDeviceID: UInt32, defaultInputDeviceID: UInt32? = nil) {
            self.inputDeviceID = inputDeviceID
            self.outputDeviceID = outputDeviceID
            self.defaultInputDeviceID = defaultInputDeviceID ?? inputDeviceID
        }
    }

    let route: Route
    private let lock = NSLock()
    private var invalidated = false

    init(route: Route) {
        self.route = route
    }

    func invalidate() {
        lock.lock()
        invalidated = true
        lock.unlock()
    }

    func canReuse(for route: Route) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !invalidated && self.route == route
    }
}
