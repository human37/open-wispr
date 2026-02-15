import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController!
    var hotkeyManager: HotkeyManager!
    var recorder: AudioRecorder!
    var transcriber: Transcriber!
    var inserter: TextInserter!
    var isPressed = false
    var isReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = Config.load()

        statusBar = StatusBarController()
        recorder = AudioRecorder()
        transcriber = Transcriber(modelSize: config.modelSize, language: config.language)
        inserter = TextInserter()

        if !Transcriber.modelExists(modelSize: config.modelSize) {
            statusBar.state = .downloading
            statusBar.updateDownloadProgress("Downloading \(config.modelSize) model...")
            print("Downloading \(config.modelSize) model (first run only)...")

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    try ModelDownloader.download(modelSize: config.modelSize)
                    DispatchQueue.main.async {
                        self.statusBar.updateDownloadProgress(nil)
                        self.finishSetup(config: config)
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Error downloading model: \(error.localizedDescription)")
                        self.statusBar.state = .idle
                        self.statusBar.updateDownloadProgress("Download failed")
                    }
                }
            }
        } else {
            finishSetup(config: config)
        }
    }

    private func finishSetup(config: Config) {
        hotkeyManager = HotkeyManager(
            keyCode: config.hotkey.keyCode,
            modifiers: config.hotkey.modifierFlags
        )

        do {
            try hotkeyManager.start(
                onKeyDown: { [weak self] in
                    self?.handleKeyDown()
                },
                onKeyUp: { [weak self] in
                    self?.handleKeyUp()
                }
            )
        } catch {
            print("Error: \(error.localizedDescription)")
            NSApplication.shared.terminate(nil)
        }

        isReady = true
        statusBar.state = .idle
        statusBar.buildMenu()

        let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)
        print("open-wispr v\(OpenWispr.version)")
        print("Hotkey: \(hotkeyDesc) (hold to record, release to transcribe)")
        print("Model: \(config.modelSize)")
        print("Ready.\n")
    }

    private func handleKeyDown() {
        guard isReady, !isPressed else { return }
        isPressed = true
        statusBar.state = .recording
        print("Recording...")
        do {
            try recorder.startRecording()
        } catch {
            print("Error starting recording: \(error.localizedDescription)")
            isPressed = false
            statusBar.state = .idle
        }
    }

    private func handleKeyUp() {
        guard isPressed else { return }
        isPressed = false

        guard let audioURL = recorder.stopRecording() else {
            print("No audio recorded")
            statusBar.state = .idle
            return
        }

        statusBar.state = .transcribing
        print("Transcribing...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let text = try self.transcriber.transcribe(audioURL: audioURL)
                DispatchQueue.main.async {
                    if !text.isEmpty {
                        print("-> \"\(text)\"")
                        self.inserter.insert(text: text)
                    } else {
                        print("(no speech detected)")
                    }
                    self.statusBar.state = .idle
                }
            } catch {
                DispatchQueue.main.async {
                    print("Error: \(error.localizedDescription)")
                    self.statusBar.state = .idle
                }
            }
        }
    }
}
