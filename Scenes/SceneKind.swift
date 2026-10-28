/// Every scene Keshiki can show. Add a case here (and its folder under Scenes/) to add a wallpaper.
enum SceneKind: String, Codable, CaseIterable {
    case koiPond = "koi-pond"

    var title: String {
        switch self {
        case .koiPond: return "Koi Pond"
        }
    }

    /// `width` in design units; displays side by side get widths in proportion, so things are the same size on each.
    func make(aspectRatio: Double, settings: KeshikiSettings, koiPond: KoiPondSettings = KoiPondSettings(), width: Double = 960) -> LivingScene {
        switch self {
        case .koiPond: return KoiPondScene(aspectRatio: aspectRatio, settings: settings, options: koiPond, width: width)
        }
    }
}
