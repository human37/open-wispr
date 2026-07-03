import AVFoundation
import CoreAudio
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var isRecording = false
    private var currentOutputURL: URL?
    var preferredDeviceID: AudioDeviceID?

    /// Called on the audio thread with a smoothed 0–1 RMS level each buffer.
    var onLevelUpdate: ((Float) -> Void)?
    // smoothedLevel is written on the audio thread and read nowhere outside this
    // class — safe. Callers receive values only via the onLevelUpdate callback.
    private var smoothedLevel: Float = 0

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

        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFmt) { [weak self] buffer, _ in
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
            }

            // Compute RMS from the raw input buffer and report a smoothed level.
            if let self, let cb = self.onLevelUpdate,
               let ch = buffer.floatChannelData {
                let n = Int(buffer.frameLength)
                var sum: Float = 0
                let ptr = ch[0]
                let step = max(1, n / 256)
                var count = 0
                var i = 0
                while i < n { let v = ptr[i]; sum += v * v; count += 1; i += step }
                let rms = count > 0 ? sqrtf(sum / Float(count)) : 0
                // Scale factor: typical conversational speech produces RMS ~0.02–0.06
                // on a 0–1 float PCM scale. Multiplying by 28 maps the mid-range of
                // normal speech (RMS ≈ 0.035) to roughly 1.0 so the bars read full
                // during active dictation and drop to near-zero in silence.
                let norm = min(1.0, rms * 28)
                // Asymmetric smoothing: fast attack (0.75), slow release (0.18).
                // Bars jump up instantly when you speak and decay gradually —
                // the same envelope shape used in broadcast audio meters.
                let alpha: Float = norm > self.smoothedLevel ? 0.75 : 0.18
                self.smoothedLevel = self.smoothedLevel * (1 - alpha) + norm * alpha
                cb(self.smoothedLevel)
            }
        }

        currentOutputURL = outputURL
        isRecording = true
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
