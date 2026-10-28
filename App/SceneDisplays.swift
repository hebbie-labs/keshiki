import AppKit

/// Keeps one scene window on every connected display, all showing the same kind of scene.
final class SceneDisplays {
    private(set) var windows: [SceneWindow] = []
    private var kind: SceneKind?

    var windowNumbers: Set<Int> {
        Set(windows.map(\.windowNumber))
    }

    var scenes: [LivingScene] {
        windows.map(\.scene)
    }

    /// Rebuilding starts fresh scenes, so it only happens for a new kind of scene or when the displays changed.
    func show(_ kind: SceneKind, settings: KeshikiSettings, configure: (LivingScene) -> Void) {
        guard kind != self.kind || windows.map(\.frame) != NSScreen.screens.map(\.frame) else { return }
        self.kind = kind
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { screen in
            let scene = kind.make(aspectRatio: screen.frame.width / screen.frame.height, settings: settings)
            configure(scene)
            return SceneWindow(screen: screen, scene: scene)
        }
    }

    /// Moves every scene forward; only draws the ones someone can see.
    func advance(by dt: Double, drawHiddenScenes: Bool) {
        for window in windows {
            window.scene.advance(by: dt)
            if drawHiddenScenes || window.isShowing { window.drawNextFrame() }
        }
    }

    func window(at screenPoint: NSPoint) -> SceneWindow? {
        windows.first { $0.frame.contains(screenPoint) }
    }
}
