import AppKit

/// Shows the pond's small pixel image scaled up to the whole display with crisp, nearest-neighbour pixels.
final class PondView: NSView {
    private let greeting = CATextLayer()

    private static let greetingFadeIn: TimeInterval = 2.5
    private static let greetingFadeOut: TimeInterval = 9
    private static let greetingLift: CGFloat = 60

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resize
        setUpGreeting()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PondView is created in code only")
    }

    func show(_ image: CGImage?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = image
        CATransaction.commit()
    }

    /// Fades "good morning" in above the spot where the koi gather (`spot` is 0...1, origin top-left).
    func greet(at spot: Point) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        greeting.position = CGPoint(x: bounds.width * spot.x, y: bounds.height * (1 - spot.y) + Self.greetingLift)
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.greetingFadeIn) { [weak self] in self?.greeting.opacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.greetingFadeOut) { [weak self] in self?.greeting.opacity = 0 }
    }

    private func setUpGreeting() {
        greeting.string = "good morning"
        greeting.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .semibold)
        greeting.fontSize = 15
        greeting.foregroundColor = NSColor(calibratedRed: 0.99, green: 0.96, blue: 0.89, alpha: 1).cgColor
        greeting.shadowOpacity = 0.45
        greeting.shadowOffset = CGSize(width: 0, height: -2)
        greeting.shadowRadius = 0
        greeting.alignmentMode = .center
        greeting.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        greeting.bounds = CGRect(x: 0, y: 0, width: 200, height: 22)
        greeting.opacity = 0
        layer?.addSublayer(greeting)
    }
}
