import Foundation

public class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    static let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

    private var onProgress: ((Double) -> Void)?
    private var completion: ((Error?) -> Void)?
    private var destPath: URL?

    public static func download(modelSize: String, onProgress: ((Double) -> Void)? = nil) throws {
        let modelFileName = "ggml-\(modelSize).bin"
        let modelsDir = Config.configDir.appendingPathComponent("models")
        let destPath = modelsDir.appendingPathComponent(modelFileName)

        if FileManager.default.fileExists(atPath: destPath.path) {
            print("Model '\(modelSize)' already exists at \(destPath.path)")
            return
        }

        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let urlString = "\(baseURL)/\(modelFileName)"
        guard let url = URL(string: urlString) else {
            throw ModelDownloadError.downloadFailed
        }

        print("Downloading \(modelSize) model from \(urlString)...")

        let downloader = ModelDownloader()
        downloader.onProgress = onProgress
        downloader.destPath = destPath

        let semaphore = DispatchSemaphore(value: 0)
        var downloadError: Error?

        downloader.completion = { error in
            downloadError = error
            semaphore.signal()
        }

        let session = URLSession(configuration: .default, delegate: downloader, delegateQueue: nil)
        let task = session.downloadTask(with: url)
        task.resume()

        semaphore.wait()
        session.invalidateAndCancel()

        if let error = downloadError {
            throw error
        }

        print("Model downloaded to \(destPath.path)")
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let destPath = destPath else {
            completion?(ModelDownloadError.downloadFailed)
            return
        }
        do {
            if FileManager.default.fileExists(atPath: destPath.path) {
                try FileManager.default.removeItem(at: destPath)
            }
            try FileManager.default.moveItem(at: location, to: destPath)
            completion?(nil)
        } catch {
            completion?(error)
        }
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let percent = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100.0
        onProgress?(percent)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            completion?(error)
        }
    }
}

enum ModelDownloadError: LocalizedError {
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            return "Failed to download model"
        }
    }
}
