/// Every scene Keshiki can show. Add a case here (and its folder under Scenes/) to add a wallpaper.
enum SceneKind: String, Codable, CaseIterable {
    case koiPond = "koi-pond"

    var title: String {
        switch self {
        case .koiPond: return "Koi Pond"
        }
    }

    func make(aspectRatio: Double, settings: KeshikiSettings) -> LivingScene {
        switch self {
        case .koiPond: return KoiPondScene(aspectRatio: aspectRatio, settings: settings)
        }
    }
}
