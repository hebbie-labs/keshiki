import Foundation

/// Reads and writes Keshiki's settings, and once brings over what Wallpapers 1.x had saved.
enum SettingsStore {
    static let generalKey = SharedSettings.generalKey
    static let koiPondKey = SharedSettings.koiPondKey
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
        if key == generalKey || key == koiPondKey { shareWithSandboxes() }
    }

    /// The screensaver can't read our defaults, so it gets a copy in its container (macOS asks once whether
    /// Keshiki may access another app's data). The wallpaper extension reads our defaults directly and only
    /// needs to hear that they changed.
    static func shareWithSandboxes() {
        let defaults = UserDefaults.standard
        let shared = [generalKey, koiPondKey].reduce(into: [String: Data]()) { $0[$1] = defaults.data(forKey: $1) }
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.ScreenSaver.Engine.legacyScreenSaver/Data")
            .appendingPathComponent(SharedSettings.fileInHome)
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        (shared as NSDictionary).write(to: file, atomically: true)
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFNotificationName(SharedSettings.changedNotification as CFString), nil, nil, true)
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
