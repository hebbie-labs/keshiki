import AppKit

/// Keeps one scene window on every connected display, all showing the same kind of scene.
final class SceneDisplays {
    private(set) var windows: [SceneWindow] = []
    private var kind: SceneKind?
    /// Scenes render finer on power than on battery, so a switch rebuilds them.
    private var builtOnBattery = SystemConditions.isOnBattery

    var windowNumbers: Set<Int> {
        Set(windows.map(\.windowNumber))
    }

    var scenes: [LivingScene] {
        windows.map(\.scene)
    }

    /// Rebuilding starts fresh scenes, so it only happens for a new kind of scene, when the displays changed, or on a
    /// switch between power and battery.
    func show(_ kind: SceneKind, settings: KeshikiSettings, configure: (LivingScene) -> Void) {
        let onBattery = SystemConditions.isOnBattery
        guard kind != self.kind || windows.map(\.frame) != NSScreen.screens.map(\.frame) || onBattery != builtOnBattery else { return }
        self.kind = kind
        builtOnBattery = onBattery
        windows.forEach { $0.close() }
        let unitsPerPoint = Self.unitsPerPoint
        windows = NSScreen.screens.compactMap { screen in
            let scene = kind.make(aspectRatio: WaterStage.pondAspect(screenAspect: screen.frame.width / screen.frame.height), settings: settings,
                                  width: screen.frame.width * unitsPerPoint)
            configure(scene)
            return SceneWindow(screen: screen, scene: scene)
        }
    }

    /// While any display plays, every scene moves on (fish may swim over to a resting display and back); only the
    /// playing ones draw. The rest keep their last frame on screen. Returns whether anything played.
    func advance(by dt: Double, where shouldRun: (SceneWindow) -> Bool) -> Bool {
        let playing = windows.filter(shouldRun)
        guard !playing.isEmpty else { return false }
        windows.forEach { $0.scene.advance(by: dt) }
        playing.forEach { $0.render() }
        return true
    }

    /// The same design units per point on every display, so a koi is as big on each: 960 across the main one.
    static var unitsPerPoint: Double {
        960 / (NSScreen.screens.first?.frame.width ?? 960)
    }

    func window(at screenPoint: NSPoint) -> SceneWindow? {
        windows.first { $0.frame.contains(screenPoint) }
    }
}
