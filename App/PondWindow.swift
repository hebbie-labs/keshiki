import AppKit

/// A borderless window showing one pond on one display, normally tucked behind the desktop icons.
final class PondWindow: NSWindow {
    let scene: PondScene
    private let pondView: PondView

    init(screen: NSScreen, settings: PondSettings) {
        scene = PondScene(aspectRatio: screen.frame.width / screen.frame.height, settings: settings)
        pondView = PondView(frame: NSRect(origin: .zero, size: screen.frame.size))
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        contentView = pondView
        setFrame(screen.frame, display: false)
        sitBehindDesktopIcons()
        orderFront(nil)
    }

    /// Borderless windows normally can't become key, but the screensaver needs key presses.
    override var canBecomeKey: Bool { true }

    /// False while other windows cover the whole display; no point drawing then.
    var isShowing: Bool {
        occlusionState.contains(.visible)
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

    func drawNextFrame() {
        pondView.show(scene.render())
    }

    func greet(at spot: Point) {
        pondView.greet(at: spot)
    }

    /// A screen point (origin bottom-left) as 0...1 across this window (origin top-left).
    func normalizedPoint(for screenPoint: NSPoint) -> Point {
        Point(x: (screenPoint.x - frame.minX) / frame.width, y: (frame.maxY - screenPoint.y) / frame.height)
    }
}
