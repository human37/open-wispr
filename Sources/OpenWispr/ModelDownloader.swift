import Foundation

class ModelDownloader {
    static let baseURL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

    static func download(modelSize: String) throws {
        let modelFileName = "ggml-\(modelSize).bin"
        let modelsDir = Config.configDir.appendingPathComponent("models")
        let destPath = modelsDir.appendingPathComponent(modelFileName)

        if FileManager.default.fileExists(atPath: destPath.path) {
            print("Model '\(modelSize)' already exists at \(destPath.path)")
            return
        }

        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        let url = "\(baseURL)/\(modelFileName)"
        print("Downloading \(modelSize) model from \(url)...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = ["-L", "--progress-bar", "-o", destPath.path, url]
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ModelDownloadError.downloadFailed
        }

        print("Model downloaded to \(destPath.path)")
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
