import ScreenSaver

/// Keshiki as a system screensaver, which macOS also shows when the screen locks.
@objc(KeshikiSaverView)
final class KeshikiSaverView: ScreenSaverView {
    /// Settings live with the app, which a screensaver can't read; for now it always shows the koi pond.
    private var scene: LivingScene?

    private static let framesPerSecond = 30.0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1 / Self.framesPerSecond
        layer = CALayer()
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.contentsGravity = .resize
        // Since Sonoma the screensaver host keeps instances alive after stopping; free the scene explicitly.
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(releaseScene),
                                                            name: .init("com.apple.screensaver.willstop"), object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("KeshikiSaverView is created by the screensaver host only")
    }

    override var hasConfigureSheet: Bool { false }

    override func startAnimation() {
        super.startAnimation()
        scene = SceneKind.koiPond.make(aspectRatio: bounds.width / max(bounds.height, 1), settings: KeshikiSettings())
    }

    override func stopAnimation() {
        super.stopAnimation()
        releaseScene()
    }

    override func animateOneFrame() {
        guard let scene else { return }
        scene.advance(by: 1 / Self.framesPerSecond)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.contents = scene.render()
        CATransaction.commit()
    }

    @objc private func releaseScene() {
        scene = nil
        layer?.contents = nil
    }
}
