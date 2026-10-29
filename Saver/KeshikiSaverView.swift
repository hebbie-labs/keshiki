import ScreenSaver

/// Keshiki as a system screensaver, which macOS also shows when the screen locks.
@objc(KeshikiSaverView)
final class KeshikiSaverView: ScreenSaverView {
    private var stage: WaterStage?
    private let metalLayer = CAMetalLayer()

    private static let framesPerSecond = 30.0

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1 / Self.framesPerSecond
        layer = metalLayer
        wantsLayer = true
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
        let aspect = bounds.width / max(bounds.height, 1)
        // The app's settings, as the app copied them into our container.
        let scene = SharedSettings.fromFile().makeScene(aspectRatio: WaterStage.pondAspect(screenAspect: aspect))
        WaterStage.configure(metalLayer, width: scene.pixelWidth, height: Int((Double(scene.pixelWidth) / aspect).rounded()))
        stage = WaterStage(scene: scene, screenAspect: aspect)
    }

    override func stopAnimation() {
        super.stopAnimation()
        releaseScene()
    }

    override func animateOneFrame() {
        guard let stage, let drawable = metalLayer.nextDrawable() else { return }
        stage.scene.advance(by: 1 / Self.framesPerSecond)
        stage.render(into: drawable.texture) { $0.present(drawable) }
    }

    @objc private func releaseScene() {
        stage = nil
    }
}
