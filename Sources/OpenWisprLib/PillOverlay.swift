import AppKit

/// A small dark floating pill that appears near the cursor while recording or
/// transcribing. Gives immediate visual confirmation that the app is listening.
///
/// Show/hide from the main thread only. Thread-safe level updates via `level`.
public class PillOverlay {

    // MARK: - Public

    public enum PillState {
        case recording
        case transcribing
        case hidden
    }

    public var state: PillState = .hidden {
        didSet { updateAppearance() }
    }

    /// Live mic level 0–1. Written from the audio thread, read on the main
    /// thread by the animation timer. On arm64, aligned 32-bit stores are
    /// atomic at the hardware level — benign race for a display-only value.
    public var level: Float = 0

    // MARK: - Private

    private let panel: NSPanel
    private let label: NSTextField
    private let waveView: WaveView

    private var animTimer: Timer?

    // MARK: - Init

    public init() {
        let W: CGFloat = 200, H: CGFloat = 40

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: W, height: H),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        // Dark pill container
        let container = PillBackground(frame: NSRect(x: 0, y: 0, width: W, height: H))
        panel.contentView = container

        // Wave bars (bottom strip)
        waveView = WaveView(frame: NSRect(x: 12, y: 6, width: W - 24, height: 12))
        container.addSubview(waveView)

        // Status label (upper strip)
        label = NSTextField(frame: NSRect(x: 12, y: H - 22, width: W - 24, height: 16))
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.9)
        label.stringValue = "Listening"
        label.cell?.lineBreakMode = .byTruncatingTail
        container.addSubview(label)
    }

    // MARK: - Show / hide

    public func show() {
        positionNearCursor()
        panel.orderFrontRegardless()
        startAnimating()
    }

    public func hide() {
        stopAnimating()
        panel.orderOut(nil)
        level = 0
    }

    // MARK: - Private helpers

    private func positionNearCursor() {
        let cursor = NSEvent.mouseLocation       // bottom-left origin, Quartz display space
        // Use the screen that contains the cursor — not necessarily the main screen.
        // Falling back to main then first handles edge cases (display sleep, mirroring).
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(cursor, $0.frame, false) })
                        ?? NSScreen.main
                        ?? NSScreen.screens.first
        else { return }
        let sf = screen.frame
        let W = panel.frame.width, H = panel.frame.height
        var x = cursor.x + 14
        var y = cursor.y - H - 14
        // clamp inside visible area
        x = max(sf.minX + 8, min(x, sf.maxX - W - 8))
        y = max(sf.minY + 8, min(y, sf.maxY - H - 8))
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updateAppearance() {
        switch state {
        case .recording:
            label.stringValue = "Listening"
            label.textColor = NSColor.white.withAlphaComponent(0.9)
        case .transcribing:
            label.stringValue = "Transcribing…"
            label.textColor = NSColor.white.withAlphaComponent(0.6)
        case .hidden:
            break
        }
    }

    private func startAnimating() {
        stopAnimating()
        animTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.waveView.level = CGFloat(self.level)
            self.waveView.needsDisplay = true
        }
    }

    private func stopAnimating() {
        animTimer?.invalidate()
        animTimer = nil
        waveView.level = 0
        waveView.needsDisplay = true
    }
}

// MARK: - Dark pill background view

private class PillBackground: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.height / 2
        let path = NSBezierPath(roundedRect: bounds, xRadius: r, yRadius: r)
        NSColor(white: 0.10, alpha: 0.95).setFill()
        path.fill()
        NSColor(white: 1.0, alpha: 0.15).setStroke()
        path.lineWidth = 0.5
        path.stroke()
    }
    override var isOpaque: Bool { false }
}

// MARK: - Wave bar view

private class WaveView: NSView {
    var level: CGFloat = 0   // 0–1, set by animation timer

    private let n = 10
    // Apple blue accent
    private let accent = NSColor(calibratedRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)

    override func draw(_ dirtyRect: NSRect) {
        let bw: CGFloat = 3, gap: CGFloat = 2.5
        let total = CGFloat(n) * bw + CGFloat(n - 1) * gap
        var x = (bounds.width - total) / 2
        let midY = bounds.midY

        for i in 0..<n {
            // bell-curve envelope: centre bars taller
            let centre = 1.0 - abs(CGFloat(i) - CGFloat(n - 1) / 2) / (CGFloat(n - 1) / 2)
            let env = 0.25 + 0.75 * centre
            let h = max(2, min(bounds.height, 2 + level * env * (bounds.height - 2)))
            let alpha = 0.45 + 0.55 * (h / bounds.height)
            accent.withAlphaComponent(alpha).setFill()
            let bar = NSRect(x: x, y: midY - h / 2, width: bw, height: h)
            NSBezierPath(roundedRect: bar, xRadius: bw / 2, yRadius: bw / 2).fill()
            x += bw + gap
        }
    }
    override var isOpaque: Bool { false }
}
