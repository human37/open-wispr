import AVFoundation
import CWhisper
import Foundation

public final class WhisperEngine {
    public static let shared = WhisperEngine()
    private let queue = DispatchQueue(label: "OpenWispr.WhisperEngine", qos: .userInitiated)

    public init() {}

    public func preload(modelPath: String) {
        queue.async {
            let startedAt = DispatchTime.now().uptimeNanoseconds
            if cwhisper_init(modelPath) {
                let ms = (DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
                print("WhisperEngine: pre-loaded model in \(ms) ms: \(modelPath)")
            } else {
                print("WhisperEngine: failed to pre-load model: \(modelPath)")
            }
        }
    }

    public func ensureLoaded(modelPath: String) -> Bool {
        queue.sync {
            cwhisper_init(modelPath)
        }
    }

    public func unload() {
        queue.sync {
            cwhisper_free()
        }
    }

    public func isLoaded() -> Bool {
        cwhisper_is_loaded()
    }

    public func transcribe(
        audioURL: URL,
        language: String,
        prompt: String?,
        spokenPunctuation: Bool
    ) throws -> String {
        guard var pcm = try load16kHzPCM(from: audioURL), !pcm.isEmpty else {
            return ""
        }
        if pcm.count < 1600 {
            pcm.append(contentsOf: [Float](repeating: 0.0, count: 1600 - pcm.count))
        }

        return try queue.sync {
            let suppressRegex = spokenPunctuation ? "[,\\.\\?!;:\\-—]" : nil
            let startedAt = DispatchTime.now().uptimeNanoseconds
            guard let cStr = cwhisper_transcribe(
                pcm,
                Int32(pcm.count),
                language,
                prompt,
                suppressRegex,
                4
            ) else {
                throw TranscriberError.transcriptionFailed
            }
            defer { cwhisper_free_string(cStr) }
            let ms = (DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000
            print("WhisperEngine: transcribed in \(ms) ms (in-memory)")
            return String(cString: cStr)
        }
    }

    private func load16kHzPCM(from url: URL) throws -> [Float]? {
        let file = try AVAudioFile(forReading: url)
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        ) else {
            return nil
        }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0 else { return [] }

        guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else {
            return nil
        }
        try file.read(into: sourceBuffer)

        // Fast path: already 16kHz mono float32
        if file.processingFormat.sampleRate == 16000 &&
            file.processingFormat.channelCount == 1 &&
            file.processingFormat.commonFormat == .pcmFormatFloat32 {
            guard let channelData = sourceBuffer.floatChannelData else { return nil }
            return Array(UnsafeBufferPointer(start: channelData[0], count: Int(sourceBuffer.frameLength)))
        }

        // Conversion path if input file has different rate or channels
        guard let converter = AVAudioConverter(from: file.processingFormat, to: targetFormat) else {
            return nil
        }
        let targetFrameCapacity = AVAudioFrameCount(Double(sourceBuffer.frameLength) * 16000.0 / file.processingFormat.sampleRate) + 100
        guard let targetBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: targetFrameCapacity) else {
            return nil
        }

        var error: NSError?
        var hasSupplied = false
        converter.convert(to: targetBuffer, error: &error) { _, outStatus in
            if hasSupplied {
                outStatus.pointee = .noDataNow
                return nil
            }
            hasSupplied = true
            outStatus.pointee = .haveData
            return sourceBuffer
        }

        if let error = error {
            throw error
        }

        guard let targetData = targetBuffer.floatChannelData else { return nil }
        return Array(UnsafeBufferPointer(start: targetData[0], count: Int(targetBuffer.frameLength)))
    }
}
