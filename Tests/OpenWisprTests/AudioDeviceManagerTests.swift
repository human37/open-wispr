import CoreAudio
import XCTest
@testable import OpenWisprLib

final class AudioDeviceManagerTests: XCTestCase {

    func testAirPodsPlaybackReferenceIsNotAMicrophone() {
        XCTAssertFalse(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [kAudioStreamTerminalTypeHeadphones],
            outputTerminalTypes: [kAudioStreamTerminalTypeHeadphones], transportType: kAudioDeviceTransportTypeBluetooth
        ))
    }

    func testAirPodsMicrophoneRemainsAvailable() {
        XCTAssertTrue(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [kAudioStreamTerminalTypeMicrophone],
            outputTerminalTypes: [], transportType: kAudioDeviceTransportTypeBluetooth
        ))
    }

    func testBuiltInSpeakerReferenceIsNotAMicrophone() {
        XCTAssertFalse(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [kAudioStreamTerminalTypeUnknown],
            outputTerminalTypes: [0x0301], transportType: kAudioDeviceTransportTypeBuiltIn
        ))
    }

    func testBuiltInMicrophoneWithUSBAudioTerminalTypeRemainsAvailable() {
        XCTAssertTrue(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [0x0201], outputTerminalTypes: [], transportType: kAudioDeviceTransportTypeBuiltIn
        ))
    }

    func testUnknownContinuityMicrophoneRemainsAvailable() {
        XCTAssertTrue(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [kAudioStreamTerminalTypeUnknown], outputTerminalTypes: [], transportType: nil
        ))
    }

    func testUnknownUSBDuplexInputRemainsAvailable() {
        XCTAssertTrue(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [kAudioStreamTerminalTypeUnknown],
            outputTerminalTypes: [0x0301], transportType: kAudioDeviceTransportTypeUSB
        ))
    }

    func testRealMicrophoneIsKeptAlongsideReferenceStreams() {
        XCTAssertTrue(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [kAudioStreamTerminalTypeUnknown, kAudioStreamTerminalTypeMicrophone],
            outputTerminalTypes: [kAudioStreamTerminalTypeSpeaker], transportType: kAudioDeviceTransportTypeBuiltIn
        ))
    }

    func testUnavailableTerminalMetadataDoesNotHideInput() {
        XCTAssertTrue(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [nil], outputTerminalTypes: [0x0301], transportType: kAudioDeviceTransportTypeBuiltIn
        ))
    }

    func testDeviceWithoutInputStreamsIsExcluded() {
        XCTAssertFalse(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [], outputTerminalTypes: [0x0301], transportType: kAudioDeviceTransportTypeBuiltIn
        ))
    }

    func testUSBAudioPlaybackTerminalIsExcluded() {
        XCTAssertFalse(AudioDeviceManager.hasRecordingInput(
            inputTerminalTypes: [0x0302], outputTerminalTypes: [0x0302], transportType: kAudioDeviceTransportTypeUSB
        ))
    }

    func testResolveWithoutUIDFallsBackToLegacyID() {
        XCTAssertEqual(
            AudioDeviceManager.resolveConfiguredDeviceID(uid: nil, legacyID: 42),
            42
        )
    }

    func testResolveWithoutUIDAndWithoutLegacyIDReturnsNil() {
        XCTAssertNil(AudioDeviceManager.resolveConfiguredDeviceID(uid: nil, legacyID: nil))
    }

    func testResolveWithUnknownUIDReturnsNilInsteadOfStaleID() {
        // The stored numeric ID must not be trusted when the UID it was
        // saved with no longer matches any present device.
        XCTAssertNil(
            AudioDeviceManager.resolveConfiguredDeviceID(
                uid: "OpenWisprTests:NoSuchDevice:UID",
                legacyID: 42
            )
        )
    }
}
