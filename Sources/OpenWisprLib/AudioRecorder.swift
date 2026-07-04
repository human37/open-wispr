import AVFoundation
import CoreAudio
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var isRecording = false
    private var currentOutputURL: URL?
    var preferredDeviceID: AudioDeviceID?

    // Called on the main queue with a normalized 0...1 input level for visualization.
    var onLevel: ((Float) -> Void)?

    func prewarm() {
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()

        if let deviceID = preferredDeviceID,
           deviceID != AudioDeviceManager.getDefaultInputDeviceID() {
            setInputDevice(deviceID, on: engine)
        }

        _ = engine.inputNode
        engine.prepare()
        audioEngine = engine
    }

    /// Stop and release the engine. Call before changing input device or on shutdown.
    func teardown() {
        if isRecording {
            audioEngine?.inputNode.removeTap(onBus: 0)
            isRecording = false
            currentOutputURL = nil
        }
        audioEngine?.stop()
        audioEngine = nil
    }

    /// Re-prewarm with the current preferredDeviceID. Use after a config change.
    func reload() {
        teardown()
        prewarm()
    }

    func startRecording(to outputURL: URL) throws {
        guard !isRecording else { return }

        if audioEngine == nil {
            prewarm()
        }

        guard let engine = audioEngine else {
            throw NSError(
                domain: "OpenWispr.AudioRecorder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Audio engine is not available"]
            )
        }

        try engine.start()

        let inputFmt = engine.inputNode.outputFormat(forBus: 0)

        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]

        let file = try AVAudioFile(forWriting: outputURL, settings: settings)
        let converter = AVAudioConverter(from: inputFmt, to: recordingFormat)
        // Capture by value so the tap closure doesn't retain self.
        let levelCallback = onLevel

        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFmt) { buffer, _ in
            guard let converter = converter else { return }

            let convertedBuffer = AVAudioPCMBuffer(
                pcmFormat: recordingFormat,
                frameCapacity: AVAudioFrameCount(
                    Double(buffer.frameLength) * 16000.0 / inputFmt.sampleRate
                )
            )!

            var error: NSError?
            converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            if error == nil && convertedBuffer.frameLength > 0 {
                try? file.write(from: convertedBuffer)
                AudioRecorder.reportLevel(from: convertedBuffer, to: levelCallback)
            }
        }

        currentOutputURL = outputURL
        isRecording = true
    }

    private static func reportLevel(from buffer: AVAudioPCMBuffer, to onLevel: ((Float) -> Void)?) {
        guard let onLevel = onLevel,
              let channel = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frameCount {
            let sample = channel[i]
            sum += sample * sample
        }
        let rms = frameCount > 0 ? sqrt(sum / Float(frameCount)) : 0

        // Map RMS to a perceptual 0...1 range: speech rarely exceeds ~0.3 RMS,
        // so scale up and clamp, then apply a curve so quieter speech still
        // drives visible movement.
        let scaled = min(1.0, rms * 7.5)
        let level = powf(scaled, 0.5)

        DispatchQueue.main.async { onLevel(level) }
    }

    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        isRecording = false

        let url = currentOutputURL
        currentOutputURL = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()

        return url
    }

    private func setInputDevice(_ deviceID: AudioDeviceID, on engine: AVAudioEngine) {
        guard let audioUnit = engine.inputNode.audioUnit else {
            print("Warning: could not access audio unit to set input device")
            return
        }

        var devID = deviceID
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &devID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        if status != noErr {
            print("Warning: failed to set audio input device (status: \(status))")
        }
    }
}
