import AppKit

/// What a scene adds to the app beyond drawing itself: its own menu section and anything it does over time.
protocol SceneControls: AnyObject {
    /// Applied to every new scene, e.g. after a display is connected.
    func configure(_ scene: LivingScene)
    func menuItems() -> [NSMenuItem]
    /// Runs every half minute while the scene is showing.
    func checkIn(windows: [SceneWindow], isResting: Bool)
    /// Runs after every frame the scenes moved on, e.g. to let things cross from one display to the next.
    func advanced(windows: [SceneWindow])
}

extension SceneKind {
    func makeControls(scenes: @escaping () -> [LivingScene]) -> SceneControls {
        switch self {
        case .koiPond: return KoiPondControls(scenes: scenes)
        }
    }
}
