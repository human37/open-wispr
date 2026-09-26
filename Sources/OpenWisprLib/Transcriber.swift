import Foundation

public class Transcriber {
    private let modelSize: String
    private let language: String
    private let whisperPrompt: String?
    private let vadEnabled: Bool
    private let vadThreshold: Double
    public var spokenPunctuation: Bool = false
    public var customDictionary: [DictionaryEntry] = []

    public init(modelSize: String = "base.en", language: String = "en", whisperPrompt: String? = nil,
                vadEnabled: Bool = false, vadThreshold: Double = 0.5) {
        self.modelSize = modelSize
        self.language = language
        self.whisperPrompt = whisperPrompt
        self.vadEnabled = vadEnabled
        self.vadThreshold = vadThreshold
    }

    public func transcribe(audioURL: URL) throws -> String {
        guard let modelPath = Transcriber.findModel(modelSize: modelSize) else {
            throw TranscriberError.modelNotFound(modelSize)
        }

        // Fast path: use pre-loaded in-memory WhisperEngine if VAD is not active
        if !vadEnabled && WhisperEngine.shared.ensureLoaded(modelPath: modelPath) {
            do {
                let text = try WhisperEngine.shared.transcribe(
                    audioURL: audioURL,
                    language: language,
                    prompt: fullPrompt,
                    spokenPunctuation: spokenPunctuation
                )
                return Transcriber.stripWhisperMarkers(
                    text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } catch {
                print("WhisperEngine in-memory transcription failed, falling back to CLI: \(error.localizedDescription)")
            }
        }

        // Fallback path or VAD path via whisper-cli
        guard let whisperPath = Transcriber.findWhisperBinary() else {
            throw TranscriberError.whisperNotFound
        }

        let vadModelPath: String?
        if vadEnabled {
            guard let path = Transcriber.findVADModel() else { throw TranscriberError.vadModelNotFound }
            vadModelPath = path
        } else {
            vadModelPath = nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: whisperPath)
        process.arguments = arguments(modelPath: modelPath, audioURL: audioURL, vadModelPath: vadModelPath)

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        var stderrData = Data()
        let stderrThread = Thread {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        }
        stderrThread.start()

        let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        while !stderrThread.isFinished { Thread.sleep(forTimeInterval: 0.01) }
        process.waitUntilExit()

        let output = Transcriber.stripWhisperMarkers(
            String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )

        if process.terminationStatus != 0 {
            let stderr = String(data: stderrData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !stderr.isEmpty { fputs("whisper-cpp: \(stderr)\n", Foundation.stderr) }
            throw TranscriberError.transcriptionFailed
        }

        return output
    }

    private var fullPrompt: String? {
        let dictionaryPrompt = DictionaryPostProcessor.buildPrompt(from: customDictionary)
        let prompt = [effectiveWhisperPrompt, dictionaryPrompt.isEmpty ? nil : dictionaryPrompt]
            .compactMap { $0 }
            .joined(separator: " ")
        return prompt.isEmpty ? nil : prompt
    }

    func arguments(modelPath: String, audioURL: URL, vadModelPath: String? = nil) -> [String] {
        var args = [
            "-m", modelPath,
            "-f", audioURL.path,
            "-l", language,
            "-nt",
            "-mc", "0",
            "-bs", "1",           // Greedy decoding for lowest latency
            "-bo", "1",
            "-nf",                // Disable temperature fallback loops
            "-t", "4",            // Explicit M4 thread count
            "--suppress-nst",     // Suppress non-speech tokens
        ]
        if let prompt = fullPrompt {
            args += ["--prompt", prompt]
        }
        if spokenPunctuation {
            args += ["--suppress-regex", "[,\\.\\?!;:\\-—]"]
        }
        if vadEnabled, let vadModelPath {
            args += ["--vad", "--vad-model", vadModelPath,
                     "--vad-threshold", String(vadThreshold)]
        }

        return args
    }

    private var effectiveWhisperPrompt: String? {
        guard let whisperPrompt else { return nil }
        return whisperPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : whisperPrompt
    }

    private static let knownMarkers: Set<String> = [
        "BLANK_AUDIO", "blank_audio",
        "Music", "MUSIC", "music",
        "Applause", "APPLAUSE", "applause",
        "Laughter", "LAUGHTER", "laughter",
        "silence", "Silence", "SILENCE",
        "SOUND", "Sound", "sound",
        "NOISE", "Noise", "noise",
        "INAUDIBLE", "inaudible",
    ]

    private static let markerRegex = try! NSRegularExpression(
        pattern: "[\\[\\(]\\s*([^\\]\\)]+?)\\s*[\\]\\)]"
    )

    public static func stripWhisperMarkers(_ text: String) -> String {
        let nsText = text as NSString
        let matches = markerRegex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        var result = text
        for match in matches.reversed() {
            let innerRange = match.range(at: 1)
            let inner = nsText.substring(with: innerRange)
            if knownMarkers.contains(inner) {
                let fullRange = Range(match.range, in: result)!
                result.replaceSubrange(fullRange, with: "")
            }
        }
        return result
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func findWhisperBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/whisper-cli",
            "/usr/local/bin/whisper-cli",
            "/opt/homebrew/bin/whisper-cpp",
            "/usr/local/bin/whisper-cpp",
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        for name in ["whisper-cli", "whisper-cpp"] {
            let which = Process()
            which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            which.arguments = [name]
            let pipe = Pipe()
            which.standardOutput = pipe
            which.standardError = Pipe()
            try? which.run()
            which.waitUntilExit()

            let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if let result = result, !result.isEmpty {
                return result
            }
        }

        return nil
    }

    public static func modelExists(modelSize: String) -> Bool {
        return findModel(modelSize: modelSize) != nil
    }

    static func findVADModel() -> String? {
        let name = ModelDownloader.vadModelFileName
        let candidates = [
            Config.configDir.appendingPathComponent("models/\(name)").path,
            "/opt/homebrew/share/whisper-cpp/models/\(name)",
            "/usr/local/share/whisper-cpp/models/\(name)",
        ]
        return candidates.first { ModelDownloader.isValidGGMLFile(at: URL(fileURLWithPath: $0)) }
    }

    public static func findModel(modelSize: String) -> String? {
        let modelFileName = "ggml-\(modelSize).bin"

        let candidates = [
            "\(Config.configDir.path)/models/\(modelFileName)",
            "/opt/homebrew/share/whisper-cpp/models/\(modelFileName)",
            "/usr/local/share/whisper-cpp/models/\(modelFileName)",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/.cache/whisper/\(modelFileName)",
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        return nil
    }
}

enum TranscriberError: LocalizedError {
    case whisperNotFound
    case modelNotFound(String)
    case vadModelNotFound
    case transcriptionFailed

    var errorDescription: String? {
        switch self {
        case .whisperNotFound:
            return "whisper-cpp not found. Install it with: brew install whisper-cpp"
        case .modelNotFound(let size):
            return "Whisper model '\(size)' not found. Download it with: open-wispr download-model \(size)"
        case .vadModelNotFound:
            return "Voice activity model not found. Restart OpenWispr to download it, or disable voiceActivityDetection in config.json."
        case .transcriptionFailed:
            return "Transcription failed"
        }
    }
}
