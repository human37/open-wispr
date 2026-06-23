import AudioToolbox
import CoreAudio
import Foundation

/// Microphone capture using a CoreAudio **input AudioQueue** writing straight to
/// a 16 kHz mono 16-bit WAV (the format whisper.cpp expects).
///
/// Why not AVAudioEngine: AVAudioEngine couples input and output. When recording
/// opens a Bluetooth headset's mic, the headset switches to HFP, which changes
/// its *output* device format (44.1 kHz A2DP → 16 kHz). AVAudioEngine halts on
/// that configuration change and posts AVAudioEngineConfigurationChange — so with
/// Bluetooth the engine died ~1s in and captured nothing.
///
/// Why not AVCaptureSession: AVFoundation does not expose Bluetooth headset mics
/// as AVCaptureDevices on macOS, so it cannot record from them at all.
///
/// An input AudioQueue is a pure capture path: it has no output node tied to the
/// playback device, so the HFP profile switch can't interrupt it, and it targets
/// the device directly by CoreAudio UID, so it works with Bluetooth mics.
final class AudioRecorder {
    var preferredDeviceID: AudioDeviceID?

    private var queue: AudioQueueRef?
    private var audioFile: AudioFileID?
    private var currentOutputURL: URL?
    private var packetIndex: Int64 = 0
    private var isRecording = false

    /// Serializes start/stop against the queue's input callback thread.
    private let lock = NSLock()

    private static let bufferCount = 3
    /// 16-bit mono @ 16 kHz, ~0.1s per buffer.
    private static let bufferByteSize: UInt32 = 16000 / 10 * 2

    private var format: AudioStreamBasicDescription = {
        var f = AudioStreamBasicDescription()
        f.mSampleRate = 16000
        f.mFormatID = kAudioFormatLinearPCM
        f.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        f.mFramesPerPacket = 1
        f.mChannelsPerFrame = 1
        f.mBitsPerChannel = 16
        f.mBytesPerFrame = 2
        f.mBytesPerPacket = 2
        return f
    }()

    /// AudioQueue starts in tens of ms and prewarming a Bluetooth device would
    /// hold it in HFP while idle, so there is intentionally nothing to prewarm.
    func prewarm() {}

    /// Stop and release any active capture. Safe to call when idle.
    func teardown() {
        _ = stopRecording()
    }

    /// Nothing is held between recordings, so a config change just means the next
    /// recording resolves the (possibly reassigned) device fresh.
    func reload() {
        teardown()
    }

    func startRecording(to outputURL: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !isRecording else { return }

        // 1. Create the destination WAV in the exact format whisper.cpp wants.
        var fileFormat = format
        var fileID: AudioFileID?
        let createStatus = AudioFileCreateWithURL(
            outputURL as CFURL, kAudioFileWAVEType, &fileFormat, .eraseFile, &fileID)
        guard createStatus == noErr, let file = fileID else {
            throw recorderError(createStatus, "Could not create audio file")
        }

        // 2. Create the input queue.
        var newQueue: AudioQueueRef?
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let queueStatus = AudioQueueNewInput(
            &format, AudioRecorder.inputCallback, selfPtr, nil, nil, 0, &newQueue)
        guard queueStatus == noErr, let q = newQueue else {
            AudioFileClose(file)
            throw recorderError(queueStatus, "Could not create input queue")
        }

        // 3. Pin the configured device by its stable UID so the queue records from
        //    the user's chosen mic rather than following the system default input.
        if let id = preferredDeviceID, let uid = AudioDeviceManager.getDeviceUID(deviceID: id) {
            var cfUID = uid as CFString
            let setStatus = AudioQueueSetProperty(
                q, kAudioQueueProperty_CurrentDevice, &cfUID, UInt32(MemoryLayout<CFString>.size))
            if setStatus != noErr {
                print("Warning: could not pin input device \(uid) on queue (status \(setStatus)); using default")
            }
        }

        // 4. Allocate and enqueue capture buffers.
        for _ in 0..<AudioRecorder.bufferCount {
            var buffer: AudioQueueBufferRef?
            let allocStatus = AudioQueueAllocateBuffer(q, AudioRecorder.bufferByteSize, &buffer)
            guard allocStatus == noErr, let b = buffer else {
                AudioQueueDispose(q, true)
                AudioFileClose(file)
                throw recorderError(allocStatus, "Could not allocate capture buffer")
            }
            AudioQueueEnqueueBuffer(q, b, 0, nil)
        }

        // 5. Commit state, then start. (State set before start so the first
        //    callback re-enqueues rather than dropping its buffer.)
        audioFile = file
        queue = q
        currentOutputURL = outputURL
        packetIndex = 0
        isRecording = true

        let startStatus = AudioQueueStart(q, nil)
        guard startStatus == noErr else {
            isRecording = false
            AudioQueueDispose(q, true)
            AudioFileClose(file)
            audioFile = nil
            queue = nil
            currentOutputURL = nil
            throw recorderError(startStatus, "Could not start input queue")
        }
    }

    func stopRecording() -> URL? {
        lock.lock()
        defer { lock.unlock() }
        guard isRecording else { return nil }
        isRecording = false

        if let q = queue {
            // Synchronous stop: blocks until the queue thread drains, so no input
            // callback can run (or touch the file) after this returns.
            AudioQueueStop(q, true)
            AudioQueueDispose(q, true)
            queue = nil
        }
        if let file = audioFile {
            AudioFileClose(file)
            audioFile = nil
        }

        let url = currentOutputURL
        currentOutputURL = nil
        return url
    }

    // MARK: - Capture callback

    private static let inputCallback: AudioQueueInputCallback = {
        userData, queue, buffer, _, numPackets, packetDescs in
        guard let userData = userData else { return }
        let recorder = Unmanaged<AudioRecorder>.fromOpaque(userData).takeUnretainedValue()
        recorder.handle(queue: queue, buffer: buffer, numPackets: numPackets, packetDescs: packetDescs)
    }

    private func handle(
        queue: AudioQueueRef,
        buffer: AudioQueueBufferRef,
        numPackets: UInt32,
        packetDescs: UnsafePointer<AudioStreamPacketDescription>?
    ) {
        // Runs on the queue's internal thread. After AudioQueueStop(_, true) returns
        // no further callbacks fire, so `audioFile` is only mutated when stopped.
        if numPackets > 0, let file = audioFile {
            var packets = numPackets
            let status = AudioFileWritePackets(
                file, false, buffer.pointee.mAudioDataByteSize, packetDescs,
                packetIndex, &packets, buffer.pointee.mAudioData)
            if status == noErr {
                packetIndex += Int64(packets)
            }
        }
        if isRecording {
            AudioQueueEnqueueBuffer(queue, buffer, 0, nil)
        }
    }

    private func recorderError(_ status: OSStatus, _ message: String) -> NSError {
        NSError(
            domain: "OpenWispr.AudioRecorder", code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: "\(message) (status \(status))"])
    }
}
