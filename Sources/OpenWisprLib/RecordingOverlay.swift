import AppKit

/// A small floating pill near the bottom of the screen that shows a live
/// microphone-level visualization while recording, so the user can see they
/// are being recorded. It never takes focus and ignores mouse events.
class RecordingOverlay {
    private var window: NSPanel?
    private var visualizer: VisualizerView?

    private static let overlaySize = NSSize(width: 148, height: 44)

    func show() {
        DispatchQueue.main.async { [weak self] in
            self?.buildIfNeeded()
            guard let self = self, let window = self.window else { return }

            self.reposition()
            self.visualizer?.reset()
            self.visualizer?.isActive = true

            window.alphaValue = 0
            window.orderFrontRegardless()
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                window.animator().alphaValue = 1
            }
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let window = self.window else { return }
            self.visualizer?.isActive = false
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.22
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
    }

    func update(level: Float) {
        visualizer?.push(level: level)
    }

    private func buildIfNeeded() {
        guard window == nil else { return }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: RecordingOverlay.overlaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let vis = VisualizerView(frame: NSRect(origin: .zero, size: RecordingOverlay.overlaySize))
        panel.contentView = vis

        window = panel
        visualizer = vis
    }

    private func reposition() {
        guard let window = window,
              let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = RecordingOverlay.overlaySize
        let x = frame.midX - size.width / 2
        let y = frame.minY + 96
        window.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

/// Draws a rounded translucent pill with a row of bars that react to the mic
/// level. When inactive the bars settle to a flat resting state.
private class VisualizerView: NSView {
    private let barCount = 13
    private var heights: [CGFloat]
    private var targets: [CGFloat]
    private var timer: Timer?
    private var currentLevel: CGFloat = 0
    // Rotates the per-bar noise so the wave shifts sideways over time.
    private var phase: CGFloat = 0

    var isActive: Bool = false {
        didSet {
            if isActive { startTimer() } else { /* keep animating down to rest */ }
        }
    }

    override init(frame frameRect: NSRect) {
        heights = Array(repeating: 0.12, count: barCount)
        targets = Array(repeating: 0.12, count: barCount)
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been used") }

    func reset() {
        currentLevel = 0
        for i in 0..<barCount {
            heights[i] = 0.12
            targets[i] = 0.12
        }
        needsDisplay = true
    }

    func push(level: Float) {
        currentLevel = CGFloat(max(0, min(1, level)))
    }

    private func startTimer() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        phase += 0.35

        // Bars taper toward the edges so the center is liveliest.
        let mid = CGFloat(barCount - 1) / 2
        var allResting = true
        for i in 0..<barCount {
            let distance = abs(CGFloat(i) - mid) / mid
            let taper = 1.0 - distance * 0.55
            let wobble = 0.5 + 0.5 * sin(phase + CGFloat(i) * 0.9)
            let rest: CGFloat = 0.10
            if isActive {
                let target = rest + currentLevel * taper * (0.45 + 0.85 * wobble)
                targets[i] = max(rest, min(1.0, target))
            } else {
                targets[i] = rest
            }
            // Ease current toward target (snappy enough to show peaks).
            heights[i] += (targets[i] - heights[i]) * 0.45
            if abs(heights[i] - rest) > 0.02 { allResting = false }
        }

        // Decay the level so bars fall when the mic goes quiet.
        currentLevel *= 0.82

        needsDisplay = true

        // Once faded out and settled, stop the timer to save CPU.
        if !isActive && allResting {
            stopTimer()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bounds = self.bounds

        // Pill background.
        let bg = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor(calibratedWhite: 0.10, alpha: 0.82).setFill()
        bg.fill()

        let inset: CGFloat = 16
        let usableWidth = bounds.width - inset * 2
        let barSpacing = usableWidth / CGFloat(barCount)
        let barWidth: CGFloat = 3
        let maxBarHeight = bounds.height - 14
        let centerY = bounds.midY

        NSColor.white.setFill()
        for i in 0..<barCount {
            let h = max(barWidth, heights[i] * maxBarHeight)
            let x = inset + barSpacing * CGFloat(i) + (barSpacing - barWidth) / 2
            let y = centerY - h / 2
            let barRect = NSRect(x: x, y: y, width: barWidth, height: h)
            NSBezierPath(roundedRect: barRect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        }
    }
}
