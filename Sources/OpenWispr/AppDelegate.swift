import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController!
    var hotkeyManager: HotkeyManager?
    var recorder: AudioRecorder!
    var transcriber: Transcriber!
    var inserter: TextInserter!
    var isPressed = false
    var isReady = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        recorder = AudioRecorder()
        inserter = TextInserter()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setup()
        }
    }

    private func setup() {
        let config = Config.load()
        transcriber = Transcriber(modelSize: config.modelSize, language: config.language)

        DispatchQueue.main.async { self.statusBar.buildMenu() }

        if Transcriber.findWhisperBinary() == nil {
            print("Error: whisper-cpp not found. Install it with: brew install whisper-cpp")
            return
        }

        Permissions.ensureMicrophone()

        if !AXIsProcessTrusted() {
            print("Waiting for Accessibility permission...")
            print("Enable OpenWispr in System Settings → Privacy & Security → Accessibility")
            while !AXIsProcessTrusted() {
                Thread.sleep(forTimeInterval: 2)
            }
            print("Accessibility: granted")
        }

        if !Transcriber.modelExists(modelSize: config.modelSize) {
            DispatchQueue.main.async {
                self.statusBar.state = .downloading
                self.statusBar.updateDownloadProgress("Downloading \(config.modelSize) model...")
            }
            print("Downloading \(config.modelSize) model...")
            do {
                try ModelDownloader.download(modelSize: config.modelSize)
            } catch {
                print("Error downloading model: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.statusBar.updateDownloadProgress("Download failed")
                }
                return
            }
            DispatchQueue.main.async {
                self.statusBar.updateDownloadProgress(nil)
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.startListening(config: config)
        }
    }

    private func startListening(config: Config) {
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

    private func handleKeyDown() {
        guard isReady, !isPressed else { return }
        isPressed = true
        statusBar.state = .recording
        do {
            try recorder.startRecording()
        } catch {
            print("Error: \(error.localizedDescription)")
            isPressed = false
            statusBar.state = .idle
        }
    }

    private func handleKeyUp() {
        guard isPressed else { return }
        isPressed = false

        guard let audioURL = recorder.stopRecording() else {
            statusBar.state = .idle
            return
        }

        statusBar.state = .transcribing

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let text = try self.transcriber.transcribe(audioURL: audioURL)
                DispatchQueue.main.async {
                    if !text.isEmpty {
                        self.inserter.insert(text: text)
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
