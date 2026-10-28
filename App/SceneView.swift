import AppKit

/// Shows a scene's small pixel image scaled up to the whole display with crisp, nearest-neighbour pixels.
final class SceneView: NSView {
    private let caption = CATextLayer()

    private static let captionFadeIn: TimeInterval = 2.5
    private static let captionFadeOut: TimeInterval = 9
    private static let captionLift: CGFloat = 60

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resize
        setUpCaption()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SceneView is created in code only")
    }

    func show(_ image: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = image
        CATransaction.commit()
    }

    /// Fades a short line of text in and out above `spot` (0...1, origin top-left).
    func showCaption(_ text: String, at spot: Point) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        caption.string = text
        caption.position = CGPoint(x: bounds.width * spot.x, y: bounds.height * (1 - spot.y) + Self.captionLift)
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.captionFadeIn) { [weak self] in self?.caption.opacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.captionFadeOut) { [weak self] in self?.caption.opacity = 0 }
    }

    private func setUpCaption() {
        caption.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
        caption.fontSize = 15
        caption.foregroundColor = NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.89, alpha: 1).cgColor
        caption.shadowOpacity = 0.45
        caption.shadowOffset = CGSize(width: 0, height: -2)
        caption.shadowRadius = 0
        caption.alignmentMode = .center
        caption.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        caption.bounds = CGRect(x: 0, y: 0, width: 240, height: 22)
        caption.opacity = 0
        layer?.addSublayer(caption)
    }
}
