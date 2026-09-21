import CoreAudio
import Foundation

struct AudioInputDevice {
    let id: AudioDeviceID
    let uid: String?
    let name: String
    let isDefault: Bool
}

class AudioDeviceManager {
    static func listInputDevices() -> [AudioInputDevice] {
        let defaultID = getDefaultInputDeviceID()

        var propertySize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize
        )
        guard status == noErr else { return [] }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &propertySize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        var result: [AudioInputDevice] = []
        for deviceID in deviceIDs {
            guard hasInputStreams(deviceID: deviceID),
                  !isVirtualDevice(deviceID: deviceID),
                  let name = getDeviceName(deviceID: deviceID) else { continue }
            result.append(AudioInputDevice(
                id: deviceID,
                uid: getDeviceUID(deviceID: deviceID),
                name: name,
                isDefault: deviceID == defaultID
            ))
        }
        return result
    }

    static func getDefaultInputDeviceID() -> AudioDeviceID {
        getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultInputDevice)
    }

    static func getDefaultOutputDeviceID() -> AudioDeviceID {
        getDefaultDeviceID(selector: kAudioHardwarePropertyDefaultOutputDevice)
    }

    private static func getDefaultDeviceID(selector: AudioObjectPropertySelector) -> AudioDeviceID {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0, nil,
            &size,
            &deviceID
        )
        return deviceID
    }

    /// Resolve the configured input device to a current AudioDeviceID.
    /// A stored UID wins over the numeric ID, because AudioDeviceIDs are not
    /// stable across reboots or device replugs while UIDs are. If a UID is
    /// set but no longer present, returns nil (system default) rather than
    /// trusting the possibly-reassigned numeric ID.
    static func resolveConfiguredDeviceID(uid: String?, legacyID: AudioDeviceID?) -> AudioDeviceID? {
        guard let uid = uid else { return legacyID }
        return listInputDevices().first(where: { $0.uid == uid })?.id
    }

    static func getDeviceUID(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &uid)
        guard status == noErr, let cfUID = uid?.takeRetainedValue() else { return nil }
        return cfUID as String
    }

    private static func isVirtualDevice(deviceID: AudioDeviceID) -> Bool {
        var transportType: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &transportType)
        guard status == noErr else { return false }
        return transportType == kAudioDeviceTransportTypeAggregate
            || transportType == kAudioDeviceTransportTypeVirtual
    }

    private static func hasInputStreams(deviceID: AudioDeviceID) -> Bool {
        let inputTypes = streamTerminalTypes(deviceID: deviceID, scope: kAudioObjectPropertyScopeInput)
        let outputTypes = streamTerminalTypes(deviceID: deviceID, scope: kAudioObjectPropertyScopeOutput)
        let transport = uint32Property(deviceID, selector: kAudioDevicePropertyTransportType)
        return hasRecordingInput(inputTerminalTypes: inputTypes, outputTerminalTypes: outputTypes, transportType: transport)
    }

    static func hasRecordingInput(inputTerminalTypes: [UInt32?], outputTerminalTypes: [UInt32?], transportType: UInt32?) -> Bool {
        inputTerminalTypes.contains { terminal in
            guard let terminal else { return true }
            guard !isPlaybackTerminal(terminal) else { return false }
            if terminal != kAudioStreamTerminalTypeUnknown { return true }
            return transportType != kAudioDeviceTransportTypeBuiltIn
                || !outputTerminalTypes.contains { $0.map(isPlaybackTerminal) ?? false }
        }
    }

    private static func isPlaybackTerminal(_ terminal: UInt32) -> Bool {
        switch terminal {
        case kAudioStreamTerminalTypeSpeaker, kAudioStreamTerminalTypeHeadphones,
             kAudioStreamTerminalTypeLFESpeaker, kAudioStreamTerminalTypeReceiverSpeaker,
             0x0300...0x0307:
            return true
        default:
            return false
        }
    }

    private static func uint32Property(_ objectID: AudioObjectID, selector: AudioObjectPropertySelector) -> UInt32? {
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, &value)
        return status == noErr ? value : nil
    }

    private static func streamTerminalTypes(deviceID: AudioDeviceID, scope: AudioObjectPropertyScope) -> [UInt32?] {
        var size: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyDataSize(deviceID, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var streams = [AudioStreamID](repeating: 0, count: Int(size) / MemoryLayout<AudioStreamID>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &streams) == noErr else { return [] }
        return streams.prefix(Int(size) / MemoryLayout<AudioStreamID>.size).map {
            uint32Property($0, selector: kAudioStreamPropertyTerminalType)
        }
    }

    private static func getDeviceName(deviceID: AudioDeviceID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &name)
        guard status == noErr, let cfName = name?.takeRetainedValue() else { return nil }
        return cfName as String
    }
}
