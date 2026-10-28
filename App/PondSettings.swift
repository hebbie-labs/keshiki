import Foundation

/// What the user picked in the menu bar, kept between launches.
struct PondSettings: Codable {
    var theme = "time"
    var water = "pond"
    var mood = "calm"
    var rain = false
    var paused = false
    var callOnClick = true
    var feedOnAlt = true
    var restOnBattery = false

    private static let defaultsKey = "settings"

    static func load() -> PondSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(PondSettings.self, from: data) else { return PondSettings() }
        return saved
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }

    /// The JSON object the pond page understands, with the conditions only the app knows about.
    func javaScriptObject(paused: Bool, systemDark: Bool) -> String {
        var copy = self
        copy.paused = paused
        let encoded = (try? JSONEncoder().encode(copy)) ?? Data("{}".utf8)
        var object = (try? JSONSerialization.jsonObject(with: encoded)) as? [String: Any] ?? [:]
        object["systemDark"] = systemDark
        let json = (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
        return String(decoding: json, as: UTF8.self)
    }
}
