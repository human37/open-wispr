import AVFoundation
import AudioToolbox
import XCTest
@testable import OpenWisprLib

final class AudioRecorderTests: XCTestCase {
    func testVoiceProcessingSelectsMicrophoneOnInputBus() {
        XCTAssertEqual(AudioCaptureUnit.microphoneBus(voiceProcessing: true), 1)
    }

    func testStandardCaptureSelectsDeviceOnHALDeviceBus() {
        XCTAssertEqual(AudioCaptureUnit.microphoneBus(voiceProcessing: false), 0)
    }

    func testNativeCaptureRequestsMonoFloatAtTranscriptionRate() {
        let format = AudioCaptureUnit.recordingFormat
        XCTAssertEqual(format.sampleRate, 16000)
        XCTAssertEqual(format.channelCount, 1)
        XCTAssertEqual(format.commonFormat, .pcmFormatFloat32)
        XCTAssertFalse(format.isInterleaved)
    }

    func testRecordingFileUses16BitMonoPCM() {
        let format = AudioCaptureUnit.fileFormat
        XCTAssertEqual(format.mSampleRate, 16000)
        XCTAssertEqual(format.mChannelsPerFrame, 1)
        XCTAssertEqual(format.mBitsPerChannel, 16)
        XCTAssertEqual(format.mBytesPerFrame, 2)
        XCTAssertEqual(format.mFormatID, kAudioFormatLinearPCM)
    }

    func testStandardCaptureKeepsHardwareSampleRate() throws {
        let format = try AudioCaptureUnit.clientFormat(voiceProcessing: false, hardwareSampleRate: 48000)
        XCTAssertEqual(format.sampleRate, 48000)
        XCTAssertEqual(format.channelCount, 1)
    }

    func testVoiceProcessingUsesNativeSampleRateConversion() throws {
        let format = try AudioCaptureUnit.clientFormat(voiceProcessing: true, hardwareSampleRate: 24000)
        XCTAssertEqual(format.sampleRate, 16000)
        XCTAssertEqual(format.channelCount, 1)
    }

    func testUnavailableHardwareFormatIsRejected() {
        XCTAssertThrowsError(try AudioCaptureUnit.clientFormat(voiceProcessing: true, hardwareSampleRate: 0))
    }

    func testNativeAsyncWriterFinalizesAudioBeforeReading() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("open-wispr-writer-test-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        var file: ExtAudioFileRef?
        var format = AudioCaptureUnit.fileFormat
        XCTAssertEqual(ExtAudioFileCreateWithURL(url as CFURL, kAudioFileWAVEType, &format, nil, 0, &file), noErr)
        let writer = try XCTUnwrap(file)
        var disposed = false
        defer { if !disposed { ExtAudioFileDispose(writer) } }
        var clientFormat = AudioCaptureUnit.recordingFormat.streamDescription.pointee
        XCTAssertEqual(ExtAudioFileSetProperty(writer, kExtAudioFileProperty_ClientDataFormat,
                                               UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientFormat), noErr)
        XCTAssertEqual(ExtAudioFileWriteAsync(writer, 0, nil), noErr)
        let input = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: AudioCaptureUnit.recordingFormat, frameCapacity: 1600))
        input.frameLength = 1600
        for frame in 0..<1600 { input.floatChannelData![0][frame] = 0.25 }
        XCTAssertEqual(ExtAudioFileWriteAsync(writer, input.frameLength, input.audioBufferList), noErr)
        for frame in 0..<1600 { input.floatChannelData![0][frame] = 0 }
        XCTAssertEqual(ExtAudioFileDispose(writer), noErr)
        disposed = true

        let recorded = try AVAudioFile(forReading: url)
        XCTAssertEqual(recorded.length, 1600)
        let output = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: recorded.processingFormat, frameCapacity: 1600))
        try recorded.read(into: output)
        XCTAssertGreaterThan(output.floatChannelData![0][800], 0.24)
    }
}
