import AVFoundation
import AudioToolbox
import CoreAudio
import Foundation

final class AudioCaptureUnit {
    static let recordingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

    static var fileFormat: AudioStreamBasicDescription {
        AudioStreamBasicDescription(
            mSampleRate: 16000, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2,
            mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0
        )
    }

    static func microphoneBus(voiceProcessing: Bool) -> AudioUnitElement {
        voiceProcessing ? 1 : 0
    }

    static func clientFormat(voiceProcessing: Bool, hardwareSampleRate: Double) throws -> AVAudioFormat {
        guard hardwareSampleRate > 0,
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: voiceProcessing ? 16000 : hardwareSampleRate,
                                         channels: 1, interleaved: false) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FormatNotSupported))
        }
        return format
    }

    private var unit: AudioUnit?
    private let renderState = AudioCaptureRenderState()
    private var callbackContext: UnsafeMutableRawPointer?
    private var cleanupFailed = false
    private let listenerQueue = DispatchQueue(label: "OpenWispr.AudioDeviceChanges")
    private var listeners: [(AudioDeviceID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []

    let cacheState: AudioEngineCacheState
    let voiceProcessing: Bool

    init(route: AudioEngineCacheState.Route, voiceProcessing: Bool) throws {
        self.voiceProcessing = voiceProcessing
        cacheState = AudioEngineCacheState(route: route)
        do {
            try configure(route: route)
        } catch {
            close()
            throw error
        }
    }

    deinit { close() }

    private func configure(route: AudioEngineCacheState.Route) throws {
        var description = AudioComponentDescription(
            componentType: kAudioUnitType_Output,
            componentSubType: voiceProcessing ? kAudioUnitSubType_VoiceProcessingIO : kAudioUnitSubType_HALOutput,
            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0
        )
        guard let component = AudioComponentFindNext(nil, &description) else {
            throw NSError(domain: "OpenWispr.AudioRecorder", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "The macOS audio capture component is unavailable",
            ])
        }
        try Self.check(AudioComponentInstanceNew(component, &unit), "Create audio capture")
        guard let unit else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_Uninitialized)) }

        if !voiceProcessing {
            try set(kAudioOutputUnitProperty_EnableIO, scope: kAudioUnitScope_Input, bus: 1, value: UInt32(1))
            try set(kAudioOutputUnitProperty_EnableIO, scope: kAudioUnitScope_Output, bus: 0, value: UInt32(0))
        }
        try set(kAudioOutputUnitProperty_CurrentDevice, scope: kAudioUnitScope_Global,
                bus: Self.microphoneBus(voiceProcessing: voiceProcessing), value: route.inputDeviceID)
        if voiceProcessing {
            try set(kAudioOutputUnitProperty_CurrentDevice, scope: kAudioUnitScope_Global, bus: 0, value: route.outputDeviceID)
        }

        renderState.unit = unit
        callbackContext = Unmanaged.passRetained(renderState).toOpaque()
        let callback = AURenderCallbackStruct(inputProc: { context, flags, timestamp, _, frames, _ in
            Unmanaged<AudioCaptureRenderState>.fromOpaque(context).takeUnretainedValue().receive(flags, timestamp, frames)
        }, inputProcRefCon: callbackContext)
        try set(kAudioOutputUnitProperty_SetInputCallback, scope: kAudioUnitScope_Global,
                bus: Self.microphoneBus(voiceProcessing: voiceProcessing), value: callback)
        var hardwareFormat = AudioStreamBasicDescription()
        var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        try Self.check(AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1,
                                           &hardwareFormat, &formatSize), "Read microphone format")
        let clientFormat = try Self.clientFormat(voiceProcessing: voiceProcessing, hardwareSampleRate: hardwareFormat.mSampleRate)
        let format = clientFormat.streamDescription.pointee
        try set(kAudioUnitProperty_StreamFormat, scope: kAudioUnitScope_Output, bus: 1, value: format)

        if voiceProcessing {
            let silence = AURenderCallbackStruct(inputProc: { _, flags, _, _, _, data in
                flags.pointee.insert(.unitRenderAction_OutputIsSilence)
                if let data {
                    for buffer in UnsafeMutableAudioBufferListPointer(data) {
                        if let pointer = buffer.mData { memset(pointer, 0, Int(buffer.mDataByteSize)) }
                    }
                }
                return noErr
            }, inputProcRefCon: nil)
            try set(kAudioUnitProperty_SetRenderCallback, scope: kAudioUnitScope_Input, bus: 0, value: silence)
            try set(kAudioUnitProperty_StreamFormat, scope: kAudioUnitScope_Input, bus: 0, value: format)
            if #available(macOS 14.0, *) {
                try set(kAUVoiceIOProperty_OtherAudioDuckingConfiguration, scope: kAudioUnitScope_Global, bus: 0,
                        value: AUVoiceIOOtherAudioDuckingConfiguration(mEnableAdvancedDucking: false, mDuckingLevel: .mid))
            }
        }

        try Self.check(AudioUnitInitialize(unit), "Initialize audio capture")
        var maximumFrames: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        try Self.check(AudioUnitGetProperty(unit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0,
                                           &maximumFrames, &size), "Read audio buffer size")
        guard maximumFrames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: clientFormat, frameCapacity: maximumFrames) else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_FailedInitialization))
        }
        renderState.buffer = buffer
        try verifyDevice(route.inputDeviceID, bus: Self.microphoneBus(voiceProcessing: voiceProcessing))
        if voiceProcessing { try verifyDevice(route.outputDeviceID, bus: 0) }
        try observeDeviceChanges(route: route)
    }

    func start(to url: URL, requestedAt: UInt64) throws {
        guard let unit, let buffer = renderState.buffer else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_Uninitialized)) }
        renderState.requestedAt = requestedAt
        renderState.framesWritten = 0
        renderState.firstBufferAt = 0
        renderState.captureError = noErr
        do {
            var format = Self.fileFormat
            try Self.check(ExtAudioFileCreateWithURL(url as CFURL, kAudioFileWAVEType, &format, nil,
                                                    AudioFileFlags.eraseFile.rawValue, &renderState.file), "Create recording")
            guard let file = renderState.file else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioFileUnspecifiedError)) }
            var clientFormat = buffer.format.streamDescription.pointee
            try Self.check(ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat,
                                                   UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientFormat), "Set recording format")
            try Self.check(ExtAudioFileWriteAsync(file, 0, nil), "Prepare recording writer")
            try Self.check(AudioOutputUnitStart(unit), "Start microphone")
        } catch {
            close()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    func stop() throws {
        guard let unit else { return }
        try Self.check(AudioOutputUnitStop(unit), "Stop microphone")
        let fileStatus = renderState.closeFile()
        try Self.check(fileStatus, "Finish recording")
        try Self.check(renderState.captureError, "Capture microphone audio")
        guard renderState.framesWritten > 0 else {
            throw NSError(domain: "OpenWispr.AudioRecorder", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "The microphone did not deliver audio. Check the selected input device.",
            ])
        }
        print("Audio first buffer: \((renderState.firstBufferAt - renderState.requestedAt) / 1_000_000) ms; recorded \(renderState.framesWritten) frames")
    }

    private func observeDeviceChanges(route: AudioEngineCacheState.Route) throws {
        let devices = voiceProcessing ? Set([route.inputDeviceID, route.outputDeviceID]) : Set([route.inputDeviceID])
        for device in devices {
            for selector in [kAudioDevicePropertyDeviceIsAlive, kAudioDevicePropertyNominalSampleRate, kAudioDevicePropertyStreams] {
                var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                         mElement: kAudioObjectPropertyElementMain)
                let state = cacheState
                let listener: AudioObjectPropertyListenerBlock = { _, _ in state.invalidate() }
                try Self.check(AudioObjectAddPropertyListenerBlock(device, &address, listenerQueue, listener), "Watch audio device")
                listeners.append((device, address, listener))
            }
        }
    }

    private func verifyDevice(_ expected: AudioDeviceID, bus: AudioUnitElement) throws {
        guard let unit else { return }
        var actual: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try Self.check(AudioUnitGetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, bus,
                                           &actual, &size), "Read audio route")
        guard actual == expected else {
            throw NSError(domain: "OpenWispr.AudioRecorder", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "macOS did not select the requested audio device",
            ])
        }
    }

    private func set<T>(_ property: AudioUnitPropertyID, scope: AudioUnitScope, bus: AudioUnitElement, value: T) throws {
        guard let unit else { return }
        var value = value
        try withUnsafePointer(to: &value) { pointer in
            try Self.check(AudioUnitSetProperty(unit, property, scope, bus, pointer, UInt32(MemoryLayout<T>.size)), "Configure audio capture")
        }
    }

    private func close() {
        guard !cleanupFailed else { return }
        for (device, address, listener) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(device, &address, listenerQueue, listener)
        }
        listeners.removeAll()
        if let unit {
            AudioOutputUnitStop(unit)
            AudioUnitUninitialize(unit)
            let status = AudioComponentInstanceDispose(unit)
            self.unit = nil
            guard status == noErr else {
                cleanupFailed = true
                print("Audio capture cleanup failed (status: \(status)). Restart OpenWispr.")
                return
            }
            renderState.unit = nil
        }
        renderState.closeFile()
        if let callbackContext {
            Unmanaged<AudioCaptureRenderState>.fromOpaque(callbackContext).release()
            self.callbackContext = nil
        }
    }

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [
                NSLocalizedDescriptionKey: "\(operation) failed (status: \(status))",
            ])
        }
    }
}

private final class AudioCaptureRenderState {
    var unit: AudioUnit?
    var buffer: AVAudioPCMBuffer?
    var file: ExtAudioFileRef?
    var framesWritten: UInt64 = 0
    var captureError: OSStatus = noErr
    var firstBufferAt: UInt64 = 0
    var requestedAt: UInt64 = 0

    func receive(_ flags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, _ timestamp: UnsafePointer<AudioTimeStamp>,
                         _ frames: UInt32) -> OSStatus {
        guard let unit, let buffer, frames <= buffer.frameCapacity else {
            captureError = kAudioUnitErr_TooManyFramesToProcess
            return captureError
        }
        buffer.frameLength = frames
        let status = AudioUnitRender(unit, flags, timestamp, 1, frames, buffer.mutableAudioBufferList)
        guard status == noErr else { captureError = status; return status }
        guard let file else { return noErr }
        let writeStatus = ExtAudioFileWriteAsync(file, frames, buffer.audioBufferList)
        guard writeStatus == noErr else { captureError = writeStatus; return writeStatus }
        if framesWritten == 0 { firstBufferAt = DispatchTime.now().uptimeNanoseconds }
        framesWritten += UInt64(frames)
        return noErr
    }

    @discardableResult
    func closeFile() -> OSStatus {
        guard let file else { return noErr }
        self.file = nil
        return ExtAudioFileDispose(file)
    }

}
