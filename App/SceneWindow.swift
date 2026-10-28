import AppKit

/// A borderless window showing one scene on one display, normally tucked behind the desktop icons.
final class SceneWindow: NSWindow {
    let scene: LivingScene
    private let stage: WaterStage
    private let sceneView: SceneView

    init?(screen: NSScreen, scene: LivingScene) {
        guard let stage = WaterStage(scene: scene, screenAspect: screen.frame.width / screen.frame.height) else { return nil }
        self.scene = scene
        self.stage = stage
        sceneView = SceneView(frame: NSRect(origin: .zero, size: screen.frame.size), backingScale: screen.backingScaleFactor)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        contentView = sceneView
        setFrame(screen.frame, display: false)
        sitBehindDesktopIcons()
        orderFront(nil)
    }

    /// Borderless windows normally can't become key, but the screensaver needs key presses.
    override var canBecomeKey: Bool { true }

    /// False while other windows cover the whole display.
    var isShowing: Bool {
        occlusionState.contains(.visible)
    }

    /// Draws the next frame.
    func render() {
        guard let drawable = sceneView.metalLayer.nextDrawable() else { return }
        stage.render(into: drawable.texture) { $0.present(drawable) }
    }

    /// A still of the current frame, e.g. for the lock screen.
    func snapshot() -> CGImage? {
        let size = sceneView.metalLayer.drawableSize
        return stage.snapshot(width: Int(size.width), height: Int(size.height))
    }

    func sitBehindDesktopIcons() {
        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    func coverEverything() {
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        orderFrontRegardless()
    }

    /// `spot` runs 0...1 across the pond.
    func showCaption(_ text: String, at spot: Point) {
        sceneView.showCaption(text, at: stage.viewSpot(forPondSpot: spot))
    }

    /// A screen point (origin bottom-left) as the spot of the pond under it (0...1 across the pond, origin top-left).
    func normalizedPoint(for screenPoint: NSPoint) -> Point {
        stage.pondSpot(forViewSpot: Point(x: (screenPoint.x - frame.minX) / frame.width, y: (frame.maxY - screenPoint.y) / frame.height))
    }
}
