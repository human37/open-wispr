import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem
    private var animationTimer: Timer?
    private var animationFrame = 0
    private var downloadProgress: String?

    enum State {
        case idle
        case recording
        case transcribing
        case downloading
        case waitingForPermission
    }

    var state: State = .idle {
        didSet { updateIcon() }
    }

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = StatusBarController.drawLogo(active: false)
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    func updateDownloadProgress(_ text: String?) {
        downloadProgress = text
        buildMenu()
    }

    func buildMenu() {
        let config = Config.load()
        let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "OpenWispr v\(OpenWispr.version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        if let progress = downloadProgress {
            let dlItem = NSMenuItem(title: progress, action: nil, keyEquivalent: "")
            dlItem.isEnabled = false
            menu.addItem(dlItem)
            menu.addItem(NSMenuItem.separator())
        }

        let stateText: String
        switch state {
        case .idle: stateText = "Ready"
        case .recording: stateText = "Recording..."
        case .transcribing: stateText = "Transcribing..."
        case .downloading: stateText = "Downloading model..."
        case .waitingForPermission: stateText = "Waiting for Accessibility permission..."
        }
        let stateItem = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
        stateItem.isEnabled = false
        menu.addItem(stateItem)

        menu.addItem(NSMenuItem.separator())

        let hotkeyItem = NSMenuItem(title: "Hotkey: \(hotkeyDesc)", action: nil, keyEquivalent: "")
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        let modelItem = NSMenuItem(title: "Model: \(config.modelSize)", action: nil, keyEquivalent: "")
        modelItem.isEnabled = false
        menu.addItem(modelItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    private func updateIcon() {
        stopAnimation()

        switch state {
        case .idle:
            setIcon(StatusBarController.drawLogo(active: false))
        case .recording:
            startRecordingAnimation()
        case .transcribing:
            startTranscribingAnimation()
        case .downloading:
            startDownloadingAnimation()
        case .waitingForPermission:
            setIcon(StatusBarController.drawLockIcon())
        }
    }

    // MARK: - Recording animation: logo pulses with sound waves

    private func startRecordingAnimation() {
        animationFrame = 0
        setIcon(StatusBarController.drawRecordingFrame(0))

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % 4
            self.setIcon(StatusBarController.drawRecordingFrame(self.animationFrame))
        }
    }

    // MARK: - Transcribing animation: dots cycle

    private func startTranscribingAnimation() {
        animationFrame = 0
        setIcon(StatusBarController.drawTranscribingFrame(0))

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % 3
            self.setIcon(StatusBarController.drawTranscribingFrame(self.animationFrame))
        }
    }

    // MARK: - Downloading animation: arrow moves down

    private func startDownloadingAnimation() {
        animationFrame = 0
        setIcon(StatusBarController.drawDownloadingFrame(0))

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % 3
            self.setIcon(StatusBarController.drawDownloadingFrame(self.animationFrame))
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

    // MARK: - Custom drawn icons

    static func drawLogo(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSColor.black.setStroke()

            let barWidth: CGFloat = 2.0
            let gap: CGFloat = 2.5
            let centerX = rect.midX
            let centerY = rect.midY

            let heights: [CGFloat] = [4, 8, 12, 8, 4]
            let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
            let startX = centerX - totalWidth / 2

            for (i, height) in heights.enumerated() {
                let x = startX + CGFloat(i) * (barWidth + gap)
                let y = centerY - height / 2
                let barRect = NSRect(x: x, y: y, width: barWidth, height: height)
                if active {
                    NSBezierPath(roundedRect: barRect, xRadius: 1, yRadius: 1).fill()
                } else {
                    let path = NSBezierPath(roundedRect: barRect, xRadius: 1, yRadius: 1)
                    path.lineWidth = 1.2
                    path.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    static func drawRecordingFrame(_ frame: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()

            let barWidth: CGFloat = 2.0
            let gap: CGFloat = 2.5
            let centerX = rect.midX
            let centerY = rect.midY

            let baseHeights: [CGFloat] = [4, 8, 12, 8, 4]
            let offsets: [[CGFloat]] = [
                [0, 2, 0, -2, 0],
                [2, 0, -2, 0, 2],
                [0, -2, 0, 2, 0],
                [-2, 0, 2, 0, -2],
            ]

            let totalWidth = CGFloat(baseHeights.count) * barWidth + CGFloat(baseHeights.count - 1) * gap
            let startX = centerX - totalWidth / 2

            for (i, baseHeight) in baseHeights.enumerated() {
                let height = max(3, baseHeight + offsets[frame][i])
                let x = startX + CGFloat(i) * (barWidth + gap)
                let y = centerY - height / 2
                let barRect = NSRect(x: x, y: y, width: barWidth, height: height)
                NSBezierPath(roundedRect: barRect, xRadius: 1, yRadius: 1).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    static func drawTranscribingFrame(_ frame: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()

            let dotSize: CGFloat = 3
            let gap: CGFloat = 3.0
            let centerY = rect.midY - dotSize / 2
            let totalWidth = 3 * dotSize + 2 * gap
            let startX = rect.midX - totalWidth / 2

            for i in 0..<3 {
                let x = startX + CGFloat(i) * (dotSize + gap)
                let y = centerY + (i == frame ? 2 : 0)
                let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                NSBezierPath(ovalIn: dotRect).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    static func drawDownloadingFrame(_ frame: Int) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let centerX = rect.midX

            let basePath = NSBezierPath()
            basePath.move(to: NSPoint(x: centerX - 5, y: 3))
            basePath.line(to: NSPoint(x: centerX + 5, y: 3))
            basePath.lineWidth = 1.5
            basePath.lineCapStyle = .round
            basePath.stroke()

            let arrowY: CGFloat = 14 - CGFloat(frame) * 2
            let arrowPath = NSBezierPath()
            arrowPath.move(to: NSPoint(x: centerX, y: arrowY))
            arrowPath.line(to: NSPoint(x: centerX, y: 6))
            arrowPath.lineWidth = 1.5
            arrowPath.lineCapStyle = .round
            arrowPath.stroke()

            let headPath = NSBezierPath()
            headPath.move(to: NSPoint(x: centerX - 3, y: 9))
            headPath.line(to: NSPoint(x: centerX, y: 5))
            headPath.line(to: NSPoint(x: centerX + 3, y: 9))
            headPath.lineWidth = 1.5
            headPath.lineCapStyle = .round
            headPath.lineJoinStyle = .round
            headPath.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    static func drawLockIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let centerX = rect.midX

            let bodyRect = NSRect(x: centerX - 4, y: 2, width: 8, height: 7)
            NSBezierPath(roundedRect: bodyRect, xRadius: 1.5, yRadius: 1.5).fill()

            let shacklePath = NSBezierPath()
            shacklePath.move(to: NSPoint(x: centerX - 2.5, y: 9))
            shacklePath.curve(to: NSPoint(x: centerX + 2.5, y: 9),
                              controlPoint1: NSPoint(x: centerX - 2.5, y: 15),
                              controlPoint2: NSPoint(x: centerX + 2.5, y: 15))
            shacklePath.lineWidth = 1.8
            shacklePath.lineCapStyle = .round
            shacklePath.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }
}
