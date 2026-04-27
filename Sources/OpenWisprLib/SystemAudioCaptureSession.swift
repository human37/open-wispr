import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

public struct SystemAudioChunk {
    public let sourceURL: URL
    public let startedAt: Date
}

enum SystemAudioCaptureError: LocalizedError {
    case noDisplayAvailable
    case failedToCreateChunkFile
    case invalidSampleFormat

    var errorDescription: String? {
        switch self {
        case .noDisplayAvailable:
            return "No display available for system audio capture"
        case .failedToCreateChunkFile:
            return "Could not create a temporary audio chunk"
        case .invalidSampleFormat:
            return "Could not read captured system audio samples"
        }
    }
}

final class SystemAudioCaptureSession: NSObject, SCStreamOutput, SCStreamDelegate {
    var chunkReadyHandler: ((SystemAudioChunk) -> Void)?
    var errorHandler: ((Error) -> Void)?

    private let sampleQueue = DispatchQueue(label: "open-wispr.system-audio.samples")
    private let chunkDurationSeconds: Double
    private var stream: SCStream?
    private var currentChunkFile: AVAudioFile?
    private var currentChunkURL: URL?
    private var currentChunkStartDate: Date?
    private var currentChunkFrameCount: AVAudioFramePosition = 0
    private var currentSampleRate: Double = 48_000
    private var isCapturing = false

    init(chunkDurationSeconds: Double = 30) {
        self.chunkDurationSeconds = chunkDurationSeconds
    }

    func start(completion: @escaping (Error?) -> Void) {
        Task {
            do {
                try await startCapture()
                completion(nil)
            } catch {
                completion(error)
            }
        }
    }

    func stop(completion: @escaping (Error?) -> Void) {
        guard let stream else {
            sampleQueue.async {
                do {
                    try self.finishCurrentChunk()
                    completion(nil)
                } catch {
                    completion(error)
                }
            }
            return
        }

        stream.stopCapture(completionHandler: { error in
            self.sampleQueue.async {
                self.isCapturing = false
                let finalizeError: Error?
                do {
                    try self.finishCurrentChunk()
                    finalizeError = nil
                } catch {
                    finalizeError = error
                }
                self.stream = nil
                completion(error ?? finalizeError)
            }
        })
    }

    private func startCapture() async throws {
        let availableContent = try await SCShareableContent.current
        guard let display = availableContent.displays.first else {
            throw SystemAudioCaptureError.noDisplayAvailable
        }

        let excludedApps = availableContent.applications.filter {
            $0.bundleIdentifier == Bundle.main.bundleIdentifier
        }

        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = max(display.width, 2)
        configuration.height = max(display.height, 2)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 3
        configuration.capturesAudio = true
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        self.stream = stream
        self.isCapturing = true

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            stream.startCapture(completionHandler: { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        errorHandler?(error)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid, isCapturing else { return }

        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, _ in
                guard let description = sampleBuffer.formatDescription?.audioStreamBasicDescription,
                      let format = AVAudioFormat(
                        standardFormatWithSampleRate: description.mSampleRate,
                        channels: description.mChannelsPerFrame
                      ),
                      let pcmBuffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        bufferListNoCopy: audioBufferList.unsafePointer
                      ) else {
                    throw SystemAudioCaptureError.invalidSampleFormat
                }
                try self.write(buffer: pcmBuffer)
            }
        } catch {
            errorHandler?(error)
        }
    }

    private func write(buffer: AVAudioPCMBuffer) throws {
        if currentChunkFile == nil {
            try openChunkFile(for: buffer.format)
        }

        try currentChunkFile?.write(from: buffer)
        currentChunkFrameCount += AVAudioFramePosition(buffer.frameLength)
        currentSampleRate = buffer.format.sampleRate

        let threshold = AVAudioFramePosition(chunkDurationSeconds * currentSampleRate)
        if currentChunkFrameCount >= threshold {
            try finishCurrentChunk()
        }
    }

    private func openChunkFile(for format: AVAudioFormat) throws {
        let directory = FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent("open-wispr-meeting-\(UUID().uuidString).caf")
        currentChunkURL = url
        currentChunkStartDate = Date()
        currentChunkFrameCount = 0
        currentSampleRate = format.sampleRate
        do {
            currentChunkFile = try AVAudioFile(forWriting: url, settings: format.settings)
        } catch {
            currentChunkFile = nil
            currentChunkURL = nil
            currentChunkStartDate = nil
            throw SystemAudioCaptureError.failedToCreateChunkFile
        }
    }

    private func finishCurrentChunk() throws {
        guard let url = currentChunkURL, let startedAt = currentChunkStartDate else {
            currentChunkFile = nil
            currentChunkFrameCount = 0
            return
        }

        currentChunkFile = nil
        currentChunkURL = nil
        currentChunkStartDate = nil
        let hasAudio = currentChunkFrameCount > 0
        currentChunkFrameCount = 0

        guard hasAudio else {
            try? FileManager.default.removeItem(at: url)
            return
        }

        chunkReadyHandler?(SystemAudioChunk(sourceURL: url, startedAt: startedAt))
    }
}
