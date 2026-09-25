import Darwin
import Foundation

public final class DaemonInstanceLock {
    public static let defaultLockURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/open-wispr/daemon.lock")

    private let fileDescriptor: Int32

    private init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    public static func acquire() throws -> DaemonInstanceLock? {
        try acquire(at: defaultLockURL)
    }

    public static func acquire(at lockURL: URL) throws -> DaemonInstanceLock? {
        try FileManager.default.createDirectory(
            at: lockURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let descriptor = Darwin.open(
            lockURL.path,
            O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK | O_CLOEXEC,
            mode_t(0o600)
        )
        guard descriptor >= 0 else {
            if errno == EWOULDBLOCK {
                return nil
            }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }

        return DaemonInstanceLock(fileDescriptor: descriptor)
    }

    deinit {
        Darwin.close(fileDescriptor)
    }
}
