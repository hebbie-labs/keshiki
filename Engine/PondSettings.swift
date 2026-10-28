import Foundation

/// What the user picked in the menu bar.
struct PondSettings: Codable, Equatable {
    var theme = "time"          // time | system | dawn | day | golden | dusk | night
    var water = "pond"          // pond | deep-clear
    var mood = "calm"           // calm | playful
    var rain = false
    var paused = false
    var callOnClick = true
    var feedOnAlt = true
    var restOnBattery = false
    var lockScreenPond = true

    init() {}

    /// Tolerates settings saved by older versions that lack newer keys.
    init(from decoder: Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PondSettings()
        theme = try saved.decodeIfPresent(String.self, forKey: .theme) ?? defaults.theme
        water = try saved.decodeIfPresent(String.self, forKey: .water) ?? defaults.water
        mood = try saved.decodeIfPresent(String.self, forKey: .mood) ?? defaults.mood
        rain = try saved.decodeIfPresent(Bool.self, forKey: .rain) ?? defaults.rain
        paused = try saved.decodeIfPresent(Bool.self, forKey: .paused) ?? defaults.paused
        callOnClick = try saved.decodeIfPresent(Bool.self, forKey: .callOnClick) ?? defaults.callOnClick
        feedOnAlt = try saved.decodeIfPresent(Bool.self, forKey: .feedOnAlt) ?? defaults.feedOnAlt
        restOnBattery = try saved.decodeIfPresent(Bool.self, forKey: .restOnBattery) ?? defaults.restOnBattery
        lockScreenPond = try saved.decodeIfPresent(Bool.self, forKey: .lockScreenPond) ?? defaults.lockScreenPond
    }
}
