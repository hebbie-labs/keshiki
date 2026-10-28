import AppKit

/// A borderless window showing one scene on one display, normally tucked behind the desktop icons.
final class SceneWindow: NSWindow {
    let scene: LivingScene
    private let renderer: SceneRenderer
    private let sceneView: SceneView

    init?(screen: NSScreen, scene: LivingScene) {
        guard let renderer = SceneRenderer(scene: scene) else { return nil }
        self.scene = scene
        self.renderer = renderer
        sceneView = SceneView(frame: NSRect(origin: .zero, size: screen.frame.size), pixelWidth: scene.pixelWidth, pixelHeight: scene.pixelHeight)
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

    /// This display's share of the next frame.
    var renderJob: SceneRenderer.Job {
        SceneRenderer.Job(renderer: renderer, scene: scene, layer: sceneView.metalLayer)
    }

    /// A still of the current frame, e.g. for the lock screen.
    func snapshot() -> CGImage? {
        renderer.snapshot(scene)
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

    func showCaption(_ text: String, at spot: Point) {
        sceneView.showCaption(text, at: spot)
    }

    /// A screen point (origin bottom-left) as 0...1 across this window (origin top-left).
    func normalizedPoint(for screenPoint: NSPoint) -> Point {
        Point(x: (screenPoint.x - frame.minX) / frame.width, y: (frame.maxY - screenPoint.y) / frame.height)
    }
}
