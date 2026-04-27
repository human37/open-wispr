import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController!
    var hotkeyManager: HotkeyManager?
    var recorder: AudioRecorder!
    var transcriber: Transcriber!
    var inserter: TextInserter!
    var config: Config!
    var isPressed = false
    var isReady = false
    var isMeetingCaptureActive = false
    var isStoppingMeetingCapture = false
    var meetingCaptureSession: SystemAudioCaptureSession?
    var meetingTranscriptSession: TranscriptLogStore.TranscriptLogSession?
    let meetingChunkQueue = DispatchQueue(label: "open-wispr.meeting-transcription")
    let meetingChunkGroup = DispatchGroup()
    private var startupPreparationComplete = false
    private var hasLoggedAccessibilityGranted = false
    private var hasRequestedAccessibility = false
    public var lastTranscription: String?
    public var currentMeetingTranscriptURL: URL? {
        meetingTranscriptSession?.fileURL
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )

        statusBar = StatusBarController()
        recorder = AudioRecorder()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setup()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setup() {
        do {
            try setupInner()
        } catch {
            print("Fatal setup error: \(error.localizedDescription)")
        }
    }

    private func setupInner() throws {
        config = Config.load()
        inserter = TextInserter()
        recorder.preferredDeviceID = config.audioInputDeviceID
        if Config.effectiveMaxRecordings(config.maxRecordings) == 0 {
            RecordingStore.deleteAllRecordings()
        }
        transcriber = Transcriber(modelSize: config.modelSize, language: config.language)
        transcriber.spokenPunctuation = config.spokenPunctuation?.value ?? false
        Permissions.noteLaunchPermissionState()

        DispatchQueue.main.async {
            self.statusBar.reprocessHandler = { [weak self] url in
                self?.reprocess(audioURL: url)
            }
            self.statusBar.onConfigChange = { [weak self] newConfig in
                self?.applyConfigChange(newConfig)
            }
            self.statusBar.startMeetingCaptureHandler = { [weak self] in
                self?.startMeetingCapture()
            }
            self.statusBar.stopMeetingCaptureHandler = { [weak self] in
                self?.stopMeetingCapture()
            }
            self.statusBar.openTranscriptFolderHandler = { [weak self] in
                self?.openMeetingTranscriptFolder()
            }
            self.statusBar.openCurrentTranscriptHandler = { [weak self] in
                self?.openCurrentMeetingTranscript()
            }
            self.statusBar.buildMenu()
        }

        if Transcriber.findWhisperBinary() == nil {
            print("Error: whisper-cpp not found. Install it with: brew install whisper-cpp")
            return
        }

        Permissions.ensureMicrophone()
        requestAccessibilityIfNeeded()

        if !Transcriber.modelExists(modelSize: config.modelSize) {
            DispatchQueue.main.async {
                self.statusBar.state = .downloading
                self.statusBar.updateDownloadProgress("Downloading \(self.config.modelSize) model...")
            }
            print("Downloading \(config.modelSize) model...")
            try ModelDownloader.download(modelSize: config.modelSize) { [weak self] percent in
                DispatchQueue.main.async {
                    let pct = Int(percent)
                    self?.statusBar.updateDownloadProgress("Downloading \(self?.config.modelSize ?? "") model... \(pct)%", percent: percent)
                }
            }
            DispatchQueue.main.async {
                self.statusBar.updateDownloadProgress(nil)
            }
        }

        if let modelPath = Transcriber.findModel(modelSize: config.modelSize) {
            let modelURL = URL(fileURLWithPath: modelPath)
            if !ModelDownloader.isValidGGMLFile(at: modelURL) {
                let msg = "Model file is corrupted. Re-download with: open-wispr download-model \(config.modelSize)"
                print("Error: \(msg)")
                DispatchQueue.main.async {
                    self.statusBar.state = .error(msg)
                    self.statusBar.buildMenu()
                }
                return
            }
        }

        startupPreparationComplete = true
        DispatchQueue.main.async { [weak self] in
            self?.startListeningIfPossible()
        }
    }

    @objc private func handleApplicationDidBecomeActive() {
        if Permissions.screenCapturePermissionWasGrantedAfterLaunch() {
            presentError("Restart OpenWispr after granting Screen & System Audio Recording permission")
        }

        requestAccessibilityIfNeeded(promptUser: false)

        DispatchQueue.main.async { [weak self] in
            self?.startListeningIfPossible()
        }
    }

    private func requestAccessibilityIfNeeded(promptUser: Bool = true) {
        guard !Permissions.hasAccessibilityPermission() else {
            hasRequestedAccessibility = false
            logAccessibilityGrantedIfNeeded()
            return
        }

        if !hasRequestedAccessibility {
            print("Accessibility: not granted")
        }
        if promptUser && !hasRequestedAccessibility {
            _ = Permissions.promptAccessibility()
            Permissions.openAccessibilitySettings()
            hasRequestedAccessibility = true
        }

        DispatchQueue.main.async {
            self.statusBar.state = .waitingForPermission
            self.statusBar.buildMenu()
        }
    }

    private func logAccessibilityGrantedIfNeeded() {
        guard !hasLoggedAccessibilityGranted else { return }
        print("Accessibility: granted")
        hasLoggedAccessibilityGranted = true
    }

    private func startListeningIfPossible() {
        guard startupPreparationComplete, !isReady else { return }
        guard Permissions.hasAccessibilityPermission() else {
            statusBar.state = .waitingForPermission
            statusBar.buildMenu()
            return
        }

        logAccessibilityGrantedIfNeeded()
        startListening()
    }

    private func startListening() {
        hotkeyManager = HotkeyManager(
            keyCode: config.hotkey.keyCode,
            modifiers: config.hotkey.modifierFlags
        )

        hotkeyManager?.start(
            onKeyDown: { [weak self] in
                self?.handleKeyDown()
            },
            onKeyUp: { [weak self] in
                self?.handleKeyUp()
            }
        )

        isReady = true
        statusBar.state = .idle
        statusBar.buildMenu()

        let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)
        print("open-wispr v\(OpenWispr.version)")
        print("Hotkey: \(hotkeyDesc)")
        print("Model: \(config.modelSize)")
        print("Ready.")
    }

    public func reloadConfig() {
        let newConfig = Config.load()
        applyConfigChange(newConfig)
    }

    func applyConfigChange(_ newConfig: Config) {
        guard isReady else { return }
        let wasDownloading: Bool
        if case .downloading = statusBar.state { wasDownloading = true } else { wasDownloading = false }
        config = newConfig
        recorder.preferredDeviceID = config.audioInputDeviceID
        transcriber = Transcriber(modelSize: config.modelSize, language: config.language)
        transcriber.spokenPunctuation = config.spokenPunctuation?.value ?? false
        inserter = TextInserter()

        hotkeyManager?.stop()
        hotkeyManager = HotkeyManager(
            keyCode: config.hotkey.keyCode,
            modifiers: config.hotkey.modifierFlags
        )
        hotkeyManager?.start(
            onKeyDown: { [weak self] in self?.handleKeyDown() },
            onKeyUp: { [weak self] in self?.handleKeyUp() }
        )

        if !wasDownloading && !Transcriber.modelExists(modelSize: config.modelSize) {
            statusBar.state = .downloading
            statusBar.updateDownloadProgress("Downloading \(config.modelSize) model...")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    try ModelDownloader.download(modelSize: newConfig.modelSize) { percent in
                        DispatchQueue.main.async {
                            let pct = Int(percent)
                            self?.statusBar.updateDownloadProgress("Downloading \(newConfig.modelSize) model... \(pct)%", percent: percent)
                        }
                    }
                    DispatchQueue.main.async {
                        self?.statusBar.state = .idle
                        self?.statusBar.updateDownloadProgress(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Error downloading model: \(error.localizedDescription)")
                        self?.statusBar.state = .idle
                        self?.statusBar.updateDownloadProgress(nil)
                    }
                }
            }
        }

        statusBar.buildMenu()

        let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)
        print("Config updated: lang=\(config.language) model=\(config.modelSize) hotkey=\(hotkeyDesc)")
    }

    private func handleKeyDown() {
        guard isReady else { return }
        guard !isMeetingCaptureActive, !isStoppingMeetingCapture else { return }

        let isToggle = config.toggleMode?.value ?? false

        if isToggle {
            if isPressed {
                handleRecordingStop()
            } else {
                handleRecordingStart()
            }
        } else {
            guard !isPressed else { return }
            handleRecordingStart()
        }
    }

    private func handleKeyUp() {
        let isToggle = config.toggleMode?.value ?? false
        if isToggle { return }

        handleRecordingStop()
    }

    private func handleRecordingStart() {
        guard !isPressed else { return }
        isPressed = true
        statusBar.state = .recording
        do {
            let outputURL: URL
            if Config.effectiveMaxRecordings(config.maxRecordings) == 0 {
                outputURL = RecordingStore.tempRecordingURL()
            } else {
                outputURL = RecordingStore.newRecordingURL()
            }
            try recorder.startRecording(to: outputURL)
        } catch {
            print("Error: \(error.localizedDescription)")
            isPressed = false
            statusBar.state = .idle
        }
    }

    private func handleRecordingStop() {
        guard isPressed else { return }
        isPressed = false

        guard let audioURL = recorder.stopRecording() else {
            statusBar.state = .idle
            return
        }

        statusBar.state = .transcribing

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let maxRecordings = Config.effectiveMaxRecordings(self.config.maxRecordings)
            defer {
                if maxRecordings == 0 {
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
            do {
                let raw = try self.transcriber.transcribe(audioURL: audioURL)
                let text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
                if maxRecordings > 0 {
                    RecordingStore.prune(maxCount: maxRecordings)
                }
                DispatchQueue.main.async {
                    if !text.isEmpty {
                        self.lastTranscription = text
                        self.inserter.insert(text: text)
                    }
                    self.statusBar.state = .idle
                    self.statusBar.buildMenu()
                }
            } catch {
                if maxRecordings > 0 {
                    RecordingStore.prune(maxCount: maxRecordings)
                }
                DispatchQueue.main.async {
                    print("Error: \(error.localizedDescription)")
                    self.statusBar.state = .error(error.localizedDescription)
                    self.statusBar.buildMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if case .error = self.statusBar.state {
                            self.statusBar.state = .idle
                            self.statusBar.buildMenu()
                        }
                    }
                }
            }
        }
    }

    public func reprocess(audioURL: URL) {
        guard case .idle = statusBar.state else { return }

        statusBar.state = .transcribing

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let raw = try self.transcriber.transcribe(audioURL: audioURL)
                let text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
                DispatchQueue.main.async {
                    if !text.isEmpty {
                        self.lastTranscription = text
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        self.statusBar.state = .copiedToClipboard
                        self.statusBar.buildMenu()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.statusBar.state = .idle
                            self.statusBar.buildMenu()
                        }
                    } else {
                        self.statusBar.state = .idle
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Reprocess error: \(error.localizedDescription)")
                    self.statusBar.state = .idle
                }
            }
        }
    }

    func startMeetingCapture() {
        guard isReady, !isMeetingCaptureActive, !isStoppingMeetingCapture else { return }

        do {
            let directory = try TranscriptLogStore.validatedDirectory(path: config.meetingTranscriptDirectory)

            switch Permissions.ensureScreenCapture() {
            case .granted:
                break
            case .requiresRestart:
                presentError("Restart OpenWispr after granting Screen & System Audio Recording permission")
                return
            case .needsSystemSettings:
                Permissions.openScreenCaptureSettings()
                presentError("Use System Settings to enable Screen & System Audio Recording. If you just enabled it, restart OpenWispr.")
                return
            }

            let store = TranscriptLogStore(directory: directory)
            let session = try store.startSession(model: config.modelSize, language: config.language)
            let captureSession = SystemAudioCaptureSession()
            meetingTranscriptSession = session
            captureSession.chunkReadyHandler = { [weak self] chunk in
                self?.processMeetingChunk(chunk)
            }
            captureSession.errorHandler = { [weak self] error in
                self?.handleMeetingCaptureError(error)
            }

            statusBar.state = .meetingStarting
            statusBar.buildMenu()

            captureSession.start { [weak self] error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let error {
                        try? session.finish(at: Date())
                        self.meetingTranscriptSession = nil
                        self.presentError(error.localizedDescription)
                        return
                    }

                    self.meetingCaptureSession = captureSession
                    self.isMeetingCaptureActive = true
                    self.isStoppingMeetingCapture = false
                    self.statusBar.state = .meetingRecording
                    self.statusBar.buildMenu()
                    print("Meeting capture started: \(session.fileURL.path)")
                }
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func stopMeetingCapture() {
        guard (isMeetingCaptureActive || meetingCaptureSession != nil), !isStoppingMeetingCapture else { return }

        isStoppingMeetingCapture = true
        statusBar.state = .meetingStopping
        statusBar.buildMenu()

        meetingCaptureSession?.stop { [weak self] stopError in
            guard let self = self else { return }
            self.meetingChunkQueue.async {
                self.meetingChunkGroup.wait()

                var finalError = stopError
                if let transcriptSession = self.meetingTranscriptSession {
                    do {
                        try transcriptSession.finish(at: Date())
                    } catch {
                        finalError = finalError ?? error
                    }
                }

                DispatchQueue.main.async {
                    self.meetingCaptureSession = nil
                    self.meetingTranscriptSession = nil
                    self.isMeetingCaptureActive = false
                    self.isStoppingMeetingCapture = false

                    if let finalError {
                        self.presentError(finalError.localizedDescription)
                    } else {
                        self.statusBar.state = .idle
                        self.statusBar.buildMenu()
                        print("Meeting capture stopped.")
                    }
                }
            }
        }
    }

    private func processMeetingChunk(_ chunk: SystemAudioChunk) {
        let group = meetingChunkGroup
        group.enter()
        meetingChunkQueue.async { [weak self] in
            defer {
                try? FileManager.default.removeItem(at: chunk.sourceURL)
                group.leave()
            }
            guard let self = self else { return }

            do {
                let convertedURL = try self.convertMeetingChunkToWhisperWav(chunk.sourceURL)
                defer { try? FileManager.default.removeItem(at: convertedURL) }

                let raw = try self.transcriber.transcribe(audioURL: convertedURL)
                let text = (self.config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
                guard !text.isEmpty else { return }

                try self.meetingTranscriptSession?.append(text: text, at: chunk.startedAt)
                DispatchQueue.main.async {
                    self.statusBar.buildMenu()
                }
            } catch {
                DispatchQueue.main.async {
                    print("Meeting transcription error: \(error.localizedDescription)")
                    self.statusBar.buildMenu()
                }
            }
        }
    }

    private func convertMeetingChunkToWhisperWav(_ sourceURL: URL) throws -> URL {
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("open-wispr-meeting-\(UUID().uuidString).wav")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            "-f", "WAVE",
            "-d", "LEI16@16000",
            "-c", "1",
            sourceURL.path,
            destinationURL.path,
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw MeetingCaptureError.audioConversionFailed(stderr)
        }

        return destinationURL
    }

    private func handleMeetingCaptureError(_ error: Error) {
        DispatchQueue.main.async {
            print("Meeting capture error: \(error.localizedDescription)")
            if self.isMeetingCaptureActive || self.isStoppingMeetingCapture {
                self.presentError(error.localizedDescription)
            }
        }
    }

    func openMeetingTranscriptFolder() {
        do {
            let directory = try TranscriptLogStore.validatedDirectory(path: config.meetingTranscriptDirectory)
            NSWorkspace.shared.open(directory)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    func openCurrentMeetingTranscript() {
        guard let url = currentMeetingTranscriptURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func presentError(_ message: String) {
        print("Error: \(message)")
        statusBar.state = .error(message)
        statusBar.buildMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if case .error = self.statusBar.state {
                self.restoreStatusBarState()
                self.statusBar.buildMenu()
            }
        }
    }

    private func restoreStatusBarState() {
        if isStoppingMeetingCapture {
            statusBar.state = .meetingStopping
        } else if isMeetingCaptureActive {
            statusBar.state = .meetingRecording
        } else {
            statusBar.state = .idle
        }
    }
}

enum MeetingCaptureError: LocalizedError {
    case audioConversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .audioConversionFailed(let details):
            return details.isEmpty ? "Failed to convert captured system audio" : "Failed to convert captured system audio: \(details)"
        }
    }
}
