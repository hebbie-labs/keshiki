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
        windows = NSScreen.screens.compactMap { screen in
            let scene = kind.make(aspectRatio: WaterStage.pondAspect(screenAspect: screen.frame.width / screen.frame.height), settings: settings)
            configure(scene)
            return SceneWindow(screen: screen, scene: scene)
        }
    }

    /// Moves the scenes that should run forward and draws them.
    /// The rest keep their last frame on screen and don't simulate either, so they cost nothing.
    func advance(by dt: Double, where shouldRun: (SceneWindow) -> Bool) {
        for window in windows where shouldRun(window) {
            window.scene.advance(by: dt)
            window.render()
        }
    }

    func window(at screenPoint: NSPoint) -> SceneWindow? {
        windows.first { $0.frame.contains(screenPoint) }
    }
}
