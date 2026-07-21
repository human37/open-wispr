import AVFoundation
import XCTest
@testable import OpenWisprLib

final class AudioRecorderTests: XCTestCase {
    func testTapFormatUsesHardwareInputWhenGraphOutputRateIsStale() throws {
        let hardwareInput = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 2,
            interleaved: false
        ))
        let staleGraphOutput = try XCTUnwrap(AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 1,
            interleaved: false
        ))

        let selected = AudioRecorder.tapFormat(
            hardwareInputFormat: hardwareInput,
            graphOutputFormat: staleGraphOutput
        )

        XCTAssertEqual(selected.sampleRate, 16000)
        XCTAssertEqual(selected.channelCount, 2)
    }
}
