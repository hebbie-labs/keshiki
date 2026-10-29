import Foundation

/// The app's settings as the screensaver and the wallpaper extension see them. Both run sandboxed and can't
/// read the app's defaults on their own: the extension may read the app's preferences domain, and the app
/// leaves a copy in the screensaver's container.
struct SharedSettings {
    static let generalKey = "settings"
    static let koiPondKey = "koiPond.settings"
    static let appDomain = "com.hebbie-labs.keshiki"
    /// Posted (as a Darwin notification) whenever the app saved its settings.
    static let changedNotification = "com.hebbie-labs.keshiki.settingsChanged"
    /// Where the app leaves the copy, relative to the reader's home (inside a sandbox, its container).
    static let fileInHome = "Library/Application Support/Keshiki/settings.plist"

    var general = KeshikiSettings()
    var koiPond = KoiPondSettings()

    /// `saved` holds the encoded settings under the app's defaults keys; anything missing stays at its default.
    init(_ saved: [String: Any] = [:]) {
        if let data = saved[Self.generalKey] as? Data, let value = try? JSONDecoder().decode(KeshikiSettings.self, from: data) {
            general = value
        }
        if let data = saved[Self.koiPondKey] as? Data, let value = try? JSONDecoder().decode(KoiPondSettings.self, from: data) {
            koiPond = value
        }
    }

    /// The copy the app left in this container's home.
    static func fromFile() -> SharedSettings {
        SharedSettings(NSDictionary(contentsOfFile: NSHomeDirectory() + "/" + fileInHome) as? [String: Any] ?? [:])
    }

    /// The app's own preferences, readable from the wallpaper extension's sandbox.
    static func fromApp() -> SharedSettings {
        SharedSettings(UserDefaults(suiteName: appDomain)?.dictionaryRepresentation() ?? [:])
    }

    func makeScene(aspectRatio: Double) -> LivingScene {
        let scene = general.scene.make(aspectRatio: aspectRatio, settings: general, koiPond: koiPond)
        scene.systemDark = SystemConditions.isDarkMode
        return scene
    }
}
