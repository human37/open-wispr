import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem
    private var animationTimer: Timer?
    private var animationFrame = 0

    private let idleImage: NSImage
    private let recordingFrames: [NSImage]
    private let transcribingImage: NSImage

    enum State {
        case idle
        case recording
        case transcribing
    }

    var state: State = .idle {
        didSet { updateIcon() }
    }

    init() {
        idleImage = StatusBarController.makeSymbolImage("mic")
        recordingFrames = [
            StatusBarController.makeSymbolImage("mic.fill"),
            StatusBarController.makeSymbolImage("mic.badge.plus"),
            StatusBarController.makeSymbolImage("mic.fill"),
            StatusBarController.makeSymbolImage("waveform"),
        ]
        transcribingImage = StatusBarController.makeSymbolImage("ellipsis.circle")

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = idleImage
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    private func buildMenu() {
        let config = Config.load()
        let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "OpenWispr v\(OpenWispr.version)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let hotkeyItem = NSMenuItem(title: "Hotkey: \(hotkeyDesc)", action: nil, keyEquivalent: "")
        menu.addItem(hotkeyItem)

        let modelItem = NSMenuItem(title: "Model: \(config.modelSize)", action: nil, keyEquivalent: "")
        menu.addItem(modelItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func updateIcon() {
        stopAnimation()

        switch state {
        case .idle:
            setIcon(idleImage)
        case .recording:
            startRecordingAnimation()
        case .transcribing:
            setIcon(transcribingImage)
        }
    }

    private func startRecordingAnimation() {
        animationFrame = 0
        setIcon(recordingFrames[0])

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % self.recordingFrames.count
            self.setIcon(self.recordingFrames[self.animationFrame])
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func setIcon(_ image: NSImage) {
        DispatchQueue.main.async {
            if let button = self.statusItem.button {
                button.image = image
                button.image?.isTemplate = true
            }
        }
    }

    private static func makeSymbolImage(_ name: String) -> NSImage {
        if let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            return image.withSymbolConfiguration(config) ?? image
        }
        let fallback = NSImage(size: NSSize(width: 18, height: 18))
        return fallback
    }
}
