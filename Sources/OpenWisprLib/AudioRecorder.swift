import AVFoundation
import CoreAudio
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var inputFormat: AVAudioFormat?
    private var isRecording = false
    private var currentOutputURL: URL?
    var preferredDeviceID: AudioDeviceID?

    /// Bring the audio engine online and keep it running. Subsequent
    /// startRecording calls only need to install a tap, which is cheap;
    /// the ~600ms cost of engine.start() is paid once at app launch.
    func prewarm() {
        guard audioEngine == nil else { return }

        let engine = AVAudioEngine()

        if let deviceID = preferredDeviceID,
           deviceID != AudioDeviceManager.getDefaultInputDeviceID() {
            setInputDevice(deviceID, on: engine)
        }

        let format = engine.inputNode.outputFormat(forBus: 0)

        do {
            engine.prepare()
            try engine.start()
        } catch {
            print("Audio engine prewarm error: \(error.localizedDescription)")
            return
        }

        audioEngine = engine
        inputFormat = format
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
        inputFormat = nil
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

        guard let engine = audioEngine, let inputFmt = inputFormat else {
            throw NSError(
                domain: "OpenWispr.AudioRecorder",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Audio engine is not available"]
            )
        }

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
