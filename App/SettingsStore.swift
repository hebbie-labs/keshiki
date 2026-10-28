import Foundation

/// Reads and writes Keshiki's settings, and once brings over what Wallpapers 1.x had saved.
enum SettingsStore {
    static let generalKey = "settings"
    static let koiPondKey = "koiPond.settings"
    static let koiMemoryKey = "koiPond.memory"
    static let originalDesktopPicturesKey = "originalDesktopPictures"

    private static let previousBundleID = "com.hebbie-labs.wallpapers"
    private static let migratedKey = "migratedFromWallpapers"

    static func load<Value: Decodable>(_ key: String, default fallback: Value) -> Value {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(Value.self, from: data) else { return fallback }
        return value
    }

    static func save<Value: Encodable>(_ value: Value, as key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }

    /// The app used to be called Wallpapers. Its settings held both the general and the koi fields,
    /// so the same data seeds both; each decoder picks out its own keys.
    static func migrateFromWallpapersIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migratedKey) else { return }
        defaults.set(true, forKey: migratedKey)
        guard let previous = UserDefaults(suiteName: previousBundleID) else { return }
        if let settings = previous.data(forKey: "settings") {
            defaults.set(settings, forKey: generalKey)
            defaults.set(settings, forKey: koiPondKey)
        }
        if let memory = previous.data(forKey: "pondMemory") { defaults.set(memory, forKey: koiMemoryKey) }
        if let originals = previous.dictionary(forKey: originalDesktopPicturesKey) {
            defaults.set(originals, forKey: originalDesktopPicturesKey)
        }
    }
}
