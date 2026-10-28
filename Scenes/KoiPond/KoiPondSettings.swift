import Foundation

/// Settings only the koi pond has.
struct KoiPondSettings: Codable, Equatable {
    var mood = "calm"           // calm | playful
    var water = "pond"          // pond | deep-clear
    var callOnClick = true
    var feedOnAlt = true

    init() {}

    /// Also reads the koi fields out of settings saved by Wallpapers 1.x.
    init(from decoder: Decoder) throws {
        let saved = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = KoiPondSettings()
        mood = try saved.decodeIfPresent(String.self, forKey: .mood) ?? defaults.mood
        water = try saved.decodeIfPresent(String.self, forKey: .water) ?? defaults.water
        callOnClick = try saved.decodeIfPresent(Bool.self, forKey: .callOnClick) ?? defaults.callOnClick
        feedOnAlt = try saved.decodeIfPresent(Bool.self, forKey: .feedOnAlt) ?? defaults.feedOnAlt
    }
}
