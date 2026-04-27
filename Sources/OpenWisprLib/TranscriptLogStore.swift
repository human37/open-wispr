import Foundation

public final class TranscriptLogStore {
    private let directory: URL
    private let now: () -> Date

    static let sessionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let headerDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let lineTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    public init(directory: URL, now: @escaping () -> Date = Date.init) {
        self.directory = directory
        self.now = now
    }

    public static func validatedDirectory(path: String?) throws -> URL {
        guard let rawPath = path?.trimmingCharacters(in: .whitespacesAndNewlines), !rawPath.isEmpty else {
            throw TranscriptLogStoreError.directoryNotConfigured
        }

        let url = URL(fileURLWithPath: rawPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw TranscriptLogStoreError.directoryMissing(url.path)
        }
        guard FileManager.default.isWritableFile(atPath: url.path) else {
            throw TranscriptLogStoreError.directoryNotWritable(url.path)
        }
        return url
    }

    public func startSession(model: String, language: String) throws -> TranscriptLogSession {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let startDate = now()
        let filename = "meeting-\(Self.sessionDateFormatter.string(from: startDate)).md"
        let fileURL = directory.appendingPathComponent(filename)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        let header = [
            "# Meeting Transcript",
            "",
            "- Started: \(Self.headerDateFormatter.string(from: startDate))",
            "- Source: System Audio",
            "- Model: \(model)",
            "- Language: \(language)",
            "",
        ].joined(separator: "\n")
        try append(string: header, to: fileURL)

        return TranscriptLogSession(fileURL: fileURL)
    }

    static func linePrefix(for date: Date) -> String {
        "[\(lineTimeFormatter.string(from: date))]"
    }

    fileprivate func append(string: String, to fileURL: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw TranscriptLogStoreError.encodingFailed
        }
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            throw TranscriptLogStoreError.appendFailed(fileURL.path)
        }
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
    }

    public final class TranscriptLogSession {
        public let fileURL: URL

        fileprivate init(fileURL: URL) {
            self.fileURL = fileURL
        }

        public func append(text: String, at date: Date) throws {
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            let line = "\(TranscriptLogStore.linePrefix(for: date)) \(cleaned)\n"
            let store = TranscriptLogStore(directory: fileURL.deletingLastPathComponent())
            try store.append(string: line, to: fileURL)
        }

        public func finish(at date: Date) throws {
            let footer = "\n- Ended: \(TranscriptLogStore.headerDateFormatter.string(from: date))\n"
            let store = TranscriptLogStore(directory: fileURL.deletingLastPathComponent())
            try store.append(string: footer, to: fileURL)
        }
    }
}

public enum TranscriptLogStoreError: LocalizedError {
    case directoryNotConfigured
    case directoryMissing(String)
    case directoryNotWritable(String)
    case appendFailed(String)
    case encodingFailed

    public var errorDescription: String? {
        switch self {
        case .directoryNotConfigured:
            return "Choose a transcript folder before starting meeting capture"
        case .directoryMissing(let path):
            return "Transcript folder does not exist: \(path)"
        case .directoryNotWritable(let path):
            return "Transcript folder is not writable: \(path)"
        case .appendFailed(let path):
            return "Could not write transcript file: \(path)"
        case .encodingFailed:
            return "Could not encode transcript text"
        }
    }
}
