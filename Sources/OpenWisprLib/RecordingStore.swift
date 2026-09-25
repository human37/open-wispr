import Foundation

public struct Recording {
    public let url: URL
    public let date: Date
}

public class RecordingStore {
    public static var recordingsDir = Config.configDir.appendingPathComponent("recordings")

    static let filePrefix = "recording-"
    static let fileExtension = "wav"
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    public static func ensureDirectory() {
        do {
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        } catch {
            fputs("Warning: could not create recordings directory: \(error.localizedDescription)\n", stderr)
        }
    }

    public static func tempRecordingURL() -> URL {
        let unique = String(UUID().uuidString.prefix(8))
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("open-wispr-recording-\(unique).wav")
    }

    public static func newRecordingURL() -> URL {
        ensureDirectory()
        let timestamp = dateFormatter.string(from: Date())
        let unique = String(UUID().uuidString.prefix(8))
        let filename = "\(filePrefix)\(timestamp)-\(unique).\(fileExtension)"
        return recordingsDir.appendingPathComponent(filename)
    }

    public static func listRecordings() -> [Recording] {
        ensureDirectory()
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: recordingsDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return []
        }

        return files
            .filter { $0.pathExtension.lowercased() == fileExtension && $0.lastPathComponent.hasPrefix(filePrefix) }
            .compactMap { url -> Recording? in
                let name = url.deletingPathExtension().lastPathComponent
                let dateString = String(name.dropFirst(filePrefix.count))
                let datePart = String(dateString.prefix(17))
                guard let date = dateFormatter.date(from: datePart) else { return nil }
                return Recording(url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    public static func prune(maxCount: Int) {
        let recordings = listRecordings()
        guard recordings.count > maxCount else { return }

        let toRemove = recordings.suffix(from: maxCount)
        for recording in toRemove {
            do {
                try FileManager.default.removeItem(at: recording.url)
            } catch {
                fputs("Warning: could not remove old recording \(recording.url.path): \(error.localizedDescription)\n", stderr)
            }
        }
    }

    public static func deleteAllRecordings() {
        for recording in listRecordings() {
            do {
                try FileManager.default.removeItem(at: recording.url)
            } catch {
                fputs("Warning: could not remove recording \(recording.url.path): \(error.localizedDescription)\n", stderr)
            }
        }
    }
}
