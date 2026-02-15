import AppKit
import Foundation

let version = "0.1.0"

func printUsage() {
    print("""
    open-wispr v\(version) — Push-to-talk voice dictation for macOS

    USAGE:
        open-wispr start              Start the dictation daemon
        open-wispr set-hotkey <key>   Set the push-to-talk hotkey
        open-wispr get-hotkey         Show current hotkey
        open-wispr download-model [size]  Download a Whisper model (default: base.en)
        open-wispr status             Show configuration and status
        open-wispr --help             Show this help message

    HOTKEY EXAMPLES:
        open-wispr set-hotkey rightoption       Right Option key (default)
        open-wispr set-hotkey globe             Globe/fn key (bottom-left)
        open-wispr set-hotkey f5                F5 key
        open-wispr set-hotkey ctrl+space        Ctrl + Space
        open-wispr set-hotkey cmd+shift+d       Cmd + Shift + D

    AVAILABLE MODELS:
        tiny.en, tiny, base.en, base, small.en, small, medium.en, medium, large

    NOTE: Requires Accessibility permissions for global hotkey capture.
          Go to System Settings → Privacy & Security → Accessibility
    """)
}

func cmdStart() {
    let config = Config.load()
    let recorder = AudioRecorder()
    let transcriber = Transcriber(modelSize: config.modelSize, language: config.language)
    let inserter = TextInserter()

    let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)
    print("open-wispr v\(version)")
    print("Hotkey: \(hotkeyDesc) (hold to record, release to transcribe)")
    print("Model: \(config.modelSize)")
    print("Press Ctrl+C to stop\n")

    var isPressed = false

    let hotkeyManager = HotkeyManager(
        keyCode: config.hotkey.keyCode,
        modifiers: config.hotkey.modifierFlags
    )

    do {
        try hotkeyManager.start(
            onKeyDown: {
                guard !isPressed else { return }
                isPressed = true
                print("🎙 Recording...")
                do {
                    try recorder.startRecording()
                } catch {
                    print("Error starting recording: \(error.localizedDescription)")
                    isPressed = false
                }
            },
            onKeyUp: {
                guard isPressed else { return }
                isPressed = false

                guard let audioURL = recorder.stopRecording() else {
                    print("No audio recorded")
                    return
                }

                print("⏳ Transcribing...")
                do {
                    let text = try transcriber.transcribe(audioURL: audioURL)
                    if !text.isEmpty {
                        print("✅ \"\(text)\"")
                        inserter.insert(text: text)
                    } else {
                        print("(no speech detected)")
                    }
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        )
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }

    signal(SIGINT) { _ in
        print("\nStopping open-wispr...")
        exit(0)
    }

    RunLoop.current.run()
}

func cmdSetHotkey(_ keyString: String) {
    guard let parsed = KeyCodes.parse(keyString) else {
        print("Error: Unknown key '\(keyString)'")
        print("Run 'open-wispr --help' for examples")
        exit(1)
    }

    var config = Config.load()
    config.hotkey = HotkeyConfig(keyCode: parsed.keyCode, modifiers: parsed.modifiers)

    do {
        try config.save()
        let desc = KeyCodes.describe(keyCode: parsed.keyCode, modifiers: parsed.modifiers)
        print("Hotkey set to: \(desc)")
    } catch {
        print("Error saving config: \(error.localizedDescription)")
        exit(1)
    }
}

func cmdGetHotkey() {
    let config = Config.load()
    let desc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)
    print("Current hotkey: \(desc)")
}

func cmdDownloadModel(_ size: String) {
    do {
        try ModelDownloader.download(modelSize: size)
    } catch {
        print("Error: \(error.localizedDescription)")
        exit(1)
    }
}

func cmdStatus() {
    let config = Config.load()
    let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)

    print("open-wispr v\(version)")
    print("Config: \(Config.configFile.path)")
    print("Hotkey: \(hotkeyDesc)")
    print("Model:  \(config.modelSize)")

    let modelPath = "\(Config.configDir.path)/models/ggml-\(config.modelSize).bin"
    let modelExists = FileManager.default.fileExists(atPath: modelPath)
    print("Model downloaded: \(modelExists ? "yes" : "no")")

    let whisperPaths = ["/opt/homebrew/bin/whisper-cpp", "/usr/local/bin/whisper-cpp"]
    let whisperFound = whisperPaths.contains { FileManager.default.fileExists(atPath: $0) }
    print("whisper-cpp installed: \(whisperFound ? "yes" : "no")")
}

let args = CommandLine.arguments
let command = args.count > 1 ? args[1] : nil

switch command {
case "start":
    cmdStart()
case "set-hotkey":
    guard args.count > 2 else {
        print("Usage: open-wispr set-hotkey <key>")
        exit(1)
    }
    cmdSetHotkey(args[2])
case "get-hotkey":
    cmdGetHotkey()
case "download-model":
    let size = args.count > 2 ? args[2] : "base.en"
    cmdDownloadModel(size)
case "status":
    cmdStatus()
case "--help", "-h", "help":
    printUsage()
case nil:
    printUsage()
default:
    print("Unknown command: \(command!)")
    printUsage()
    exit(1)
}
