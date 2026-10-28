import ScreenSaver

/// The pond as a system screensaver, which macOS also shows when the screen locks.
@objc(PondSaverView)
final class PondSaverView: ScreenSaverView {
    private var scene: PondScene?

    private static let framesPerSecond = 30.0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1 / Self.framesPerSecond
        layer = CALayer()
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resize
        // Since Sonoma the screensaver host keeps instances alive after stopping; free the pond explicitly.
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(releasePond),
                                                            name: .init("com.apple.screensaver.willstop"), object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PondSaverView is created by the screensaver host only")
    }

    override var hasConfigureSheet: Bool { false }

    override func startAnimation() {
        super.startAnimation()
        scene = PondScene(aspectRatio: bounds.width / max(bounds.height, 1), settings: PondSettings())
    }

    override func stopAnimation() {
        super.stopAnimation()
        releasePond()
    }

    override func animateOneFrame() {
        guard let scene else { return }
        scene.advance(by: 1 / Self.framesPerSecond)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = scene.render()
        CATransaction.commit()
    }

    @objc private func releasePond() {
        scene = nil
        layer?.contents = nil
    }
}
