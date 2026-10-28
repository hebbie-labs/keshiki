import Foundation

/// Settings that apply whatever scene is showing.
struct KeshikiSettings: Codable, Equatable {
    var scene = SceneKind.koiPond
    var theme = "time"          // time | system | dawn | day | golden | dusk | night
    var rain = false
    var paused = false
    var restOnBattery = false
    var showOnLockScreen = true

    init() {}

    private enum LegacyKeys: String, CodingKey {
        case lockScreenPond
    }

    /// Tolerates settings saved by older versions (including Wallpapers 1.x) that lack newer keys.
    init(from decoder: Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try decoder.container(keyedBy: LegacyKeys.self)
        let defaults = KeshikiSettings()
        scene = (try? saved.decodeIfPresent(SceneKind.self, forKey: .scene)) ?? defaults.scene
        theme = try saved.decodeIfPresent(String.self, forKey: .theme) ?? defaults.theme
        rain = try saved.decodeIfPresent(Bool.self, forKey: .rain) ?? defaults.rain
        paused = try saved.decodeIfPresent(Bool.self, forKey: .paused) ?? defaults.paused
        restOnBattery = try saved.decodeIfPresent(Bool.self, forKey: .restOnBattery) ?? defaults.restOnBattery
        showOnLockScreen = try saved.decodeIfPresent(Bool.self, forKey: .showOnLockScreen)
            ?? legacy.decodeIfPresent(Bool.self, forKey: .lockScreenPond) ?? defaults.showOnLockScreen
    }
}
