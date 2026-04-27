import AppKit

class MenuItemTarget: NSObject {
    let handler: () -> Void
    init(handler: @escaping () -> Void) { self.handler = handler }
    @objc func invoke() { handler() }
}

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var animationTimer: Timer?
    private var animationFrame = 0
    private var animationFrames: [NSImage] = []
    private var downloadProgress: String?
    private var downloadPercent: Double = 0
    private var copiedFeedback = false
    private var menuItemTargets: [MenuItemTarget] = []
    private var stateMenuItem: NSMenuItem?

    var reprocessHandler: ((URL) -> Void)?
    var onConfigChange: ((Config) -> Void)?
    var startMeetingCaptureHandler: (() -> Void)?
    var stopMeetingCaptureHandler: (() -> Void)?
    var openTranscriptFolderHandler: (() -> Void)?
    var openCurrentTranscriptHandler: (() -> Void)?

    enum State {
        case idle
        case recording
        case transcribing
        case meetingStarting
        case meetingRecording
        case meetingStopping
        case downloading
        case waitingForPermission
        case copiedToClipboard
        case error(String)
    }

    var state: State = .idle {
        didSet { updateIcon() }
    }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = StatusBarController.drawLogo(active: false)
            button.image?.isTemplate = true
        }

        buildMenu()
    }

    @objc private func copyLastTranscription() {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate,
              let text = delegate.lastTranscription else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        copiedFeedback = true
        buildMenu()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.copiedFeedback = false
            self?.buildMenu()
        }
    }

    func updateDownloadProgress(_ text: String?, percent: Double = 0) {
        downloadProgress = text
        downloadPercent = percent
        if case .downloading = state {
            setIcon(StatusBarController.drawDownloadProgress(downloadPercent))
        }
        if let text = text, let item = stateMenuItem {
            let config = Config.load()
            let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)
            item.title = "\(text) (hotkey: \(hotkeyDesc))"
        } else {
            buildMenu()
        }
    }

    private static let displayDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    func buildMenu() {
        menuItemTargets = []

        let config = Config.load()
        let hotkeyDesc = KeyCodes.describe(keyCode: config.hotkey.keyCode, modifiers: config.hotkey.modifiers)

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "OpenWispr v\(OpenWispr.version)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        let stateLabel: String
        if let progress = downloadProgress {
            stateLabel = progress
        } else {
            switch state {
            case .idle: stateLabel = "Ready"
            case .recording: stateLabel = "Recording..."
            case .transcribing: stateLabel = "Transcribing..."
            case .meetingStarting: stateLabel = "Starting meeting capture..."
            case .meetingRecording: stateLabel = "Capturing meeting audio..."
            case .meetingStopping: stateLabel = "Stopping meeting capture..."
            case .downloading: stateLabel = "Downloading model..."
            case .waitingForPermission: stateLabel = "Waiting for Accessibility permission..."
            case .copiedToClipboard: stateLabel = "Copied to clipboard"
            case .error(let message): stateLabel = "Error: \(message)"
            }
        }
        if case .waitingForPermission = state {
            let target = MenuItemTarget {
                _ = Permissions.promptAccessibility()
                Permissions.openAccessibilitySettings()
            }
            menuItemTargets.append(target)
            let stateItem = NSMenuItem(title: "Grant Accessibility Permission...", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
            stateItem.target = target
            menu.addItem(stateItem)
            stateMenuItem = stateItem
        } else {
            let stateItem = NSMenuItem(title: "\(stateLabel) (hotkey: \(hotkeyDesc))", action: nil, keyEquivalent: "")
            stateItem.isEnabled = false
            menu.addItem(stateItem)
            stateMenuItem = stateItem
        }

        menu.addItem(NSMenuItem.separator())

        let currentLang = config.language
        let langName = Config.supportedLanguages.first(where: { $0.code == currentLang })?.name ?? currentLang
        let langItem = NSMenuItem(title: "Language: \(langName)", action: nil, keyEquivalent: "")
        let langSubmenu = NSMenu()

        for (index, lang) in Config.supportedLanguages.enumerated() {
            if index == 1 {
                langSubmenu.addItem(NSMenuItem.separator())
            }
            let target = MenuItemTarget { [weak self] in
                var cfg = Config.load()
                cfg.language = lang.code
                if lang.code != "en" && cfg.modelSize.hasSuffix(".en") {
                    let base = String(cfg.modelSize.dropLast(3))
                    if Config.supportedModels.contains(base) {
                        cfg.modelSize = base
                    }
                } else if lang.code == "en" && !cfg.modelSize.hasSuffix(".en") {
                    let enVariant = cfg.modelSize + ".en"
                    if Config.supportedModels.contains(enVariant) {
                        cfg.modelSize = enVariant
                    }
                }
                try? cfg.save()
                self?.onConfigChange?(cfg)
            }
            self.menuItemTargets.append(target)
            let item = NSMenuItem(title: lang.name, action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
            item.target = target
            if lang.code == currentLang {
                item.state = .on
            }
            langSubmenu.addItem(item)
        }

        langItem.submenu = langSubmenu
        menu.addItem(langItem)

        let modelItem = NSMenuItem(title: "Model: \(config.modelSize)", action: nil, keyEquivalent: "")
        let modelSubmenu = NSMenu()

        let englishModels = Config.supportedModels.filter { Config.isEnglishOnlyModel($0) }
        let multilingualModels = Config.supportedModels.filter { !Config.isEnglishOnlyModel($0) }

        let engHeader = NSMenuItem(title: "English", action: nil, keyEquivalent: "")
        engHeader.isEnabled = false
        modelSubmenu.addItem(engHeader)

        for model in englishModels {
            let target = MenuItemTarget { [weak self] in
                var cfg = Config.load()
                cfg.modelSize = model
                if cfg.language != "en" {
                    cfg.language = "en"
                }
                try? cfg.save()
                self?.onConfigChange?(cfg)
            }
            self.menuItemTargets.append(target)
            let item = NSMenuItem(title: "  \(model)", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
            item.target = target
            if model == config.modelSize {
                item.state = .on
            }
            modelSubmenu.addItem(item)
        }

        modelSubmenu.addItem(NSMenuItem.separator())

        let multiHeader = NSMenuItem(title: "Multilingual", action: nil, keyEquivalent: "")
        multiHeader.isEnabled = false
        modelSubmenu.addItem(multiHeader)

        for model in multilingualModels {
            let target = MenuItemTarget { [weak self] in
                var cfg = Config.load()
                cfg.modelSize = model
                try? cfg.save()
                self?.onConfigChange?(cfg)
            }
            self.menuItemTargets.append(target)
            let item = NSMenuItem(title: "  \(model)", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
            item.target = target
            if model == config.modelSize {
                item.state = .on
            }
            modelSubmenu.addItem(item)
        }

        modelItem.submenu = modelSubmenu
        menu.addItem(modelItem)

        let devices = AudioDeviceManager.listInputDevices()
        let selectedDeviceID = config.audioInputDeviceID
        let currentDeviceName: String
        if let selectedID = selectedDeviceID,
           let device = devices.first(where: { $0.id == selectedID }) {
            currentDeviceName = device.name
        } else {
            currentDeviceName = "System Default"
        }
        let audioItem = NSMenuItem(title: "Audio Input: \(currentDeviceName)", action: nil, keyEquivalent: "")
        let audioSubmenu = NSMenu()
        audioSubmenu.autoenablesItems = false

        let defaultTarget = MenuItemTarget { [weak self] in
            var cfg = Config.load()
            cfg.audioInputDeviceID = nil
            try? cfg.save()
            self?.onConfigChange?(cfg)
        }
        menuItemTargets.append(defaultTarget)
        let defaultItem = NSMenuItem(title: "System Default", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
        defaultItem.target = defaultTarget
        if selectedDeviceID == nil { defaultItem.state = .on }
        audioSubmenu.addItem(defaultItem)

        if !devices.isEmpty {
            audioSubmenu.addItem(NSMenuItem.separator())
        }

        for device in devices {
            let target = MenuItemTarget { [weak self] in
                var cfg = Config.load()
                cfg.audioInputDeviceID = device.id
                try? cfg.save()
                self?.onConfigChange?(cfg)
            }
            menuItemTargets.append(target)
            let item = NSMenuItem(title: device.name, action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
            item.target = target
            if selectedDeviceID == device.id { item.state = .on }
            audioSubmenu.addItem(item)
        }

        audioItem.submenu = audioSubmenu
        menu.addItem(audioItem)

        menu.addItem(NSMenuItem.separator())

        let transcriptFolderTitle: String
        if let path = config.meetingTranscriptDirectory, !path.isEmpty {
            transcriptFolderTitle = URL(fileURLWithPath: path).lastPathComponent
        } else {
            transcriptFolderTitle = "Not Set"
        }
        let transcriptItem = NSMenuItem(title: "Meeting Transcript Folder: \(transcriptFolderTitle)", action: nil, keyEquivalent: "")
        let transcriptSubmenu = NSMenu()

        let chooseFolderTarget = MenuItemTarget { [weak self] in
            self?.chooseMeetingTranscriptFolder()
        }
        menuItemTargets.append(chooseFolderTarget)
        let chooseFolderItem = NSMenuItem(title: "Choose Folder...", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
        chooseFolderItem.target = chooseFolderTarget
        transcriptSubmenu.addItem(chooseFolderItem)

        let openFolderTarget = MenuItemTarget { [weak self] in
            self?.openTranscriptFolderHandler?()
        }
        menuItemTargets.append(openFolderTarget)
        let openFolderItem = NSMenuItem(title: "Open Folder", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
        openFolderItem.target = openFolderTarget
        openFolderItem.isEnabled = config.meetingTranscriptDirectory?.isEmpty == false
        transcriptSubmenu.addItem(openFolderItem)

        if let delegate = NSApplication.shared.delegate as? AppDelegate,
           delegate.currentMeetingTranscriptURL != nil {
            let openCurrentTarget = MenuItemTarget { [weak self] in
                self?.openCurrentTranscriptHandler?()
            }
            menuItemTargets.append(openCurrentTarget)
            let openCurrentItem = NSMenuItem(title: "Open Current Transcript", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
            openCurrentItem.target = openCurrentTarget
            transcriptSubmenu.addItem(openCurrentItem)
        }

        transcriptItem.submenu = transcriptSubmenu
        menu.addItem(transcriptItem)

        let delegate = NSApplication.shared.delegate as? AppDelegate
        let isMeetingActive = delegate?.isMeetingCaptureActive ?? false
        let isMeetingStopping = delegate?.isStoppingMeetingCapture ?? false
        let meetingActionTarget = MenuItemTarget { [weak self] in
            if isMeetingActive || isMeetingStopping {
                self?.stopMeetingCaptureHandler?()
            } else {
                self?.startMeetingCaptureHandler?()
            }
        }
        menuItemTargets.append(meetingActionTarget)
        let meetingAction = NSMenuItem(
            title: (isMeetingActive || isMeetingStopping) ? "Stop Meeting Capture" : "Start Meeting Capture",
            action: #selector(MenuItemTarget.invoke),
            keyEquivalent: "m"
        )
        meetingAction.target = meetingActionTarget
        if !isMeetingActive && !isMeetingStopping && (config.meetingTranscriptDirectory?.isEmpty != false) {
            meetingAction.isEnabled = false
        }
        menu.addItem(meetingAction)

        menu.addItem(NSMenuItem.separator())

        let toggleTarget = MenuItemTarget { [weak self] in
            var cfg = Config.load()
            let current = cfg.toggleMode?.value ?? false
            cfg.toggleMode = FlexBool(!current)
            try? cfg.save()
            self?.onConfigChange?(cfg)
        }
        menuItemTargets.append(toggleTarget)
        let toggleItem = NSMenuItem(title: "Toggle Mode", action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
        toggleItem.target = toggleTarget
        toggleItem.state = (config.toggleMode?.value ?? false) ? .on : .off
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let lastText = (NSApplication.shared.delegate as? AppDelegate)?.lastTranscription
        let copyTitle = copiedFeedback ? "Copied!" : "Copy Last Dictation"
        let copyItem = NSMenuItem(title: copyTitle, action: lastText != nil && !copiedFeedback ? #selector(copyLastTranscription) : nil, keyEquivalent: "c")
        copyItem.target = self
        if lastText == nil || copiedFeedback { copyItem.isEnabled = copiedFeedback }
        menu.addItem(copyItem)

        if Config.effectiveMaxRecordings(config.maxRecordings) > 0 {
            let recordings = RecordingStore.listRecordings()
            let reprocessItem = NSMenuItem(title: "Recent Recordings", action: nil, keyEquivalent: "")
            let submenu = NSMenu()

            if recordings.isEmpty {
                let emptyItem = NSMenuItem(title: "No recordings", action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                submenu.addItem(emptyItem)
            } else {
                for (index, recording) in recordings.enumerated() {
                    let dateStr = StatusBarController.displayDateFormatter.string(from: recording.date)
                    let label = "\(dateStr) (\(index + 1))"
                    let target = MenuItemTarget { [weak self] in
                        self?.reprocessHandler?(recording.url)
                    }
                    menuItemTargets.append(target)
                    let item = NSMenuItem(title: label, action: #selector(MenuItemTarget.invoke), keyEquivalent: "")
                    item.target = target
                    submenu.addItem(item)
                }
            }

            reprocessItem.submenu = submenu
            menu.addItem(reprocessItem)
        }

        menu.addItem(NSMenuItem.separator())

        let reloadItem = NSMenuItem(title: "Reload Configuration", action: #selector(reloadConfiguration), keyEquivalent: "r")
        reloadItem.target = self
        menu.addItem(reloadItem)

        let openItem = NSMenuItem(title: "Open Configuration", action: #selector(openConfiguration), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func reloadConfiguration() {
        guard let delegate = NSApplication.shared.delegate as? AppDelegate else { return }
        delegate.reloadConfig()
    }

    @objc private func openConfiguration() {
        let configFile = Config.configFile
        if !FileManager.default.fileExists(atPath: configFile.path) {
            let config = Config.defaultConfig
            try? config.save()
        }
        NSWorkspace.shared.open(configFile)
    }

    private func chooseMeetingTranscriptFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            var cfg = Config.load()
            cfg.meetingTranscriptDirectory = url.path
            try? cfg.save()
            onConfigChange?(cfg)
        }
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
        case .meetingStarting:
            startTranscribingAnimation()
        case .meetingRecording:
            startRecordingAnimation()
        case .meetingStopping:
            startTranscribingAnimation()
        case .downloading:
            startDownloadingAnimation()
        case .waitingForPermission:
            setIcon(StatusBarController.drawLockIcon())
        case .copiedToClipboard:
            setIcon(StatusBarController.drawCheckmarkIcon())
        case .error:
            setIcon(StatusBarController.drawWarningIcon())
        }
    }

    // MARK: - Recording animation: wave

    private static let waveFrameCount = 30

    private static func prerenderWaveFrames() -> [NSImage] {
        let count = waveFrameCount
        let baseHeights: [CGFloat] = [4, 8, 12, 8, 4]
        let minScale: CGFloat = 0.3
        let phaseOffsets: [Double] = [0.0, 0.15, 0.3, 0.45, 0.6]

        return (0..<count).map { frame in
            let t = Double(frame) / Double(count)

            let size = NSSize(width: 18, height: 18)
            let image = NSImage(size: size, flipped: false) { rect in
                NSColor.black.setFill()

                let barWidth: CGFloat = 2.0
                let gap: CGFloat = 2.5
                let radius: CGFloat = 1.5
                let centerX = rect.midX
                let centerY = rect.midY

                let totalWidth = CGFloat(baseHeights.count) * barWidth + CGFloat(baseHeights.count - 1) * gap
                let startX = centerX - totalWidth / 2

                for (i, baseHeight) in baseHeights.enumerated() {
                    let phase = t - phaseOffsets[i]
                    let scale = minScale + (1.0 - minScale) * CGFloat((sin(phase * 2.0 * .pi) + 1.0) / 2.0)
                    let height = baseHeight * scale
                    let x = startX + CGFloat(i) * (barWidth + gap)
                    let y = centerY - height / 2
                    let barRect = NSRect(x: x, y: y, width: barWidth, height: height)
                    NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()
                }
                return true
            }
            image.isTemplate = true
            return image
        }
    }

    private func startRecordingAnimation() {
        animationFrame = 0
        animationFrames = StatusBarController.prerenderWaveFrames()
        setIcon(animationFrames[0])

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % StatusBarController.waveFrameCount
            self.setIcon(self.animationFrames[self.animationFrame])
        }
    }

    // MARK: - Transcribing animation: smooth wave dots

    private static let transcribeFrameCount = 30

    private static func prerenderTranscribeFrames() -> [NSImage] {
        let count = transcribeFrameCount
        let maxBounce: CGFloat = 3.0
        return (0..<count).map { frame in
            let t = Double(frame) / Double(count)

            let size = NSSize(width: 18, height: 18)
            let image = NSImage(size: size, flipped: false) { rect in
                NSColor.black.setFill()

                let dotSize: CGFloat = 3
                let gap: CGFloat = 3.0
                let centerY = rect.midY - dotSize / 2
                let totalWidth = 3 * dotSize + 2 * gap
                let startX = rect.midX - totalWidth / 2

                for i in 0..<3 {
                    let phase = t - Double(i) * 0.15
                    let bounce = maxBounce * CGFloat(max(0, sin(phase * 2.0 * .pi)))
                    let x = startX + CGFloat(i) * (dotSize + gap)
                    let y = centerY + bounce
                    let dotRect = NSRect(x: x, y: y, width: dotSize, height: dotSize)
                    NSBezierPath(ovalIn: dotRect).fill()
                }
                return true
            }
            image.isTemplate = true
            return image
        }
    }

    private func startTranscribingAnimation() {
        animationFrame = 0
        animationFrames = StatusBarController.prerenderTranscribeFrames()
        setIcon(animationFrames[0])

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.animationFrame = (self.animationFrame + 1) % StatusBarController.transcribeFrameCount
            self.setIcon(self.animationFrames[self.animationFrame])
        }
    }

    // MARK: - Downloading: progress ring

    private static let downloadPulseFrameCount = 30

    private static func prerenderDownloadPulseFrames() -> [NSImage] {
        let count = downloadPulseFrameCount
        return (0..<count).map { frame in
            let t = Double(frame) / Double(count)
            let alpha = CGFloat(0.4 + 0.6 * (sin(t * 2.0 * .pi) + 1.0) / 2.0)
            return drawDownloadProgress(0, pulseAlpha: alpha)
        }
    }

    private func startDownloadingAnimation() {
        animationFrame = 0
        animationFrames = StatusBarController.prerenderDownloadPulseFrames()
        setIcon(animationFrames[0])

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.downloadPercent > 0 {
                self.setIcon(StatusBarController.drawDownloadProgress(self.downloadPercent))
            } else {
                self.animationFrame = (self.animationFrame + 1) % StatusBarController.downloadPulseFrameCount
                self.setIcon(self.animationFrames[self.animationFrame])
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationFrames = []
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

            let barWidth: CGFloat = 2.0
            let gap: CGFloat = 2.5
            let radius: CGFloat = 1.5
            let centerX = rect.midX
            let centerY = rect.midY

            let heights: [CGFloat] = [4, 8, 12, 8, 4]
            let totalWidth = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
            let startX = centerX - totalWidth / 2

            for (i, height) in heights.enumerated() {
                let x = startX + CGFloat(i) * (barWidth + gap)
                let y = centerY - height / 2
                let barRect = NSRect(x: x, y: y, width: barWidth, height: height)
                NSBezierPath(roundedRect: barRect, xRadius: radius, yRadius: radius).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    static func drawDownloadProgress(_ percent: Double, pulseAlpha: CGFloat = 1.0) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 6.5
            let lineWidth: CGFloat = 1.8

            NSColor.black.withAlphaComponent(0.25 * pulseAlpha).setStroke()
            let bgCircle = NSBezierPath()
            bgCircle.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            bgCircle.lineWidth = lineWidth
            bgCircle.stroke()

            if percent > 0 {
                NSColor.black.setStroke()
                let progressArc = NSBezierPath()
                let startAngle: CGFloat = 90
                let endAngle = startAngle - CGFloat(percent / 100.0) * 360.0
                progressArc.appendArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
                progressArc.lineWidth = lineWidth
                progressArc.lineCapStyle = .round
                progressArc.stroke()
            }

            NSColor.black.withAlphaComponent(pulseAlpha).setStroke()
            NSColor.black.withAlphaComponent(pulseAlpha).setFill()
            let arrowPath = NSBezierPath()
            arrowPath.move(to: NSPoint(x: center.x, y: center.y + 3))
            arrowPath.line(to: NSPoint(x: center.x, y: center.y - 3))
            arrowPath.lineWidth = 1.5
            arrowPath.lineCapStyle = .round
            arrowPath.stroke()

            let headPath = NSBezierPath()
            headPath.move(to: NSPoint(x: center.x - 2.5, y: center.y - 0.5))
            headPath.line(to: NSPoint(x: center.x, y: center.y - 3.5))
            headPath.line(to: NSPoint(x: center.x + 2.5, y: center.y - 0.5))
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

    static func drawCheckmarkIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()

            let centerX = rect.midX
            let centerY = rect.midY

            let path = NSBezierPath()
            path.move(to: NSPoint(x: centerX - 5, y: centerY + 1))
            path.line(to: NSPoint(x: centerX - 2, y: centerY - 3))
            path.line(to: NSPoint(x: centerX + 5, y: centerY + 4))
            path.lineWidth = 2.0
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()

            return true
        }
        image.isTemplate = true
        return image
    }

    static func drawWarningIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let centerX = rect.midX

            // Triangle outline
            let triangle = NSBezierPath()
            triangle.move(to: NSPoint(x: centerX, y: 16))
            triangle.line(to: NSPoint(x: centerX - 7, y: 3))
            triangle.line(to: NSPoint(x: centerX + 7, y: 3))
            triangle.close()
            triangle.lineWidth = 1.5
            triangle.lineJoinStyle = .round
            triangle.stroke()

            // Exclamation mark
            let stemRect = NSRect(x: centerX - 0.75, y: 7, width: 1.5, height: 5)
            NSBezierPath(roundedRect: stemRect, xRadius: 0.75, yRadius: 0.75).fill()
            let dotRect = NSRect(x: centerX - 1, y: 4.5, width: 2, height: 2)
            NSBezierPath(ovalIn: dotRect).fill()

            return true
        }
        image.isTemplate = true
        return image
    }
}
