import Foundation

extension PondSettings {
    private static let defaultsKey = "settings"

    static func load() -> PondSettings {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let saved = try? JSONDecoder().decode(PondSettings.self, from: data) else { return PondSettings() }
        return saved
    }

    func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(self), forKey: Self.defaultsKey)
    }
}
