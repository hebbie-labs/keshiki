import AppKit

/// Shows a scene's stage through a Metal layer. It's drawn as wide as the scene's pixel art, which keeps the
/// GPU cheap, and Core Animation scales it up to the display with crisp, nearest-neighbour pixels.
final class SceneView: NSView {
    let metalLayer = CAMetalLayer()
    private let caption = CATextLayer()

    private static let captionFadeIn: TimeInterval = 2.5
    private static let captionFadeOut: TimeInterval = 9
    private static let captionLift: CGFloat = 60

    init(frame: NSRect, pixelWidth: Int) {
        super.init(frame: frame)
        WaterStage.configure(metalLayer, width: pixelWidth, height: Int((Double(pixelWidth) * frame.height / frame.width).rounded()))
        layer = metalLayer
        wantsLayer = true
        setUpCaption()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SceneView is created in code only")
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
