import AppKit

/// The "Koi Pond" tile in System Settings → Wallpaper (and Screen Saver). The system decodes it as its own private
/// `WallpaperSettingsViewModels`, so these types mirror that shape key for key (as Phosphene found it).
enum SettingsTile {
    static let choiceID = "koi-pond"

    /// The view models, archived and read back as the system's own XPC class.
    static func viewModels(thumbnail: URL) -> AnyObject? {
        let provider = Bundle.main.bundleIdentifier ?? "com.hebbie-labs.keshiki.wallpaper"
        let id = ChoiceID(id: choiceID, descriptor: .init(provider: provider, identifier: choiceID, files: [], configuration: Data(choiceID.utf8)))
        let picture = ["image": ["url": thumbnail]]
        let item = Item(id: id, localizedName: "Koi Pond", thumbnail: picture,
                        choice: .init(id: id, provider: provider, identifier: choiceID, name: "Koi Pond",
                                      localizedDescription: "A living koi pond by Keshiki", thumbnail: picture, isDownloaded: true, options: []),
                        contentBadge: none, showInTopLevel: true, sortOrder: 0, disposability: none)
        let group = Group(id: .init(id: "keshiki"), items: [item], localizedName: "Keshiki", disposability: none, sortOrder: -100,
                          sortID: .init(id: "com.apple.wallpaper.aerials"), shouldHideItemLabels: false)
        let model = ViewModel(groups: [group], refreshPolicy: ["default": [:]], isModificationDisabled: false)
        return remapToSystemClass(Archived(value: ViewModels(desktop: model, screenSaver: model)))
    }

    /// A payload-less case of one of the system's enums, as Swift's synthesized `Codable` writes it.
    private static let none: [String: [String: String]] = ["none": [:]]

    private struct ViewModels: Encodable { var desktop, screenSaver: ViewModel }
    private struct ViewModel: Encodable {
        var groups: [Group]
        var refreshPolicy: [String: [String: String]]
        var isModificationDisabled: Bool
    }
    private struct Group: Encodable {
        var id: Name
        var items: [Item]
        var localizedName: String
        var disposability: [String: [String: String]]
        var sortOrder: Int
        var sortID: Name
        var shouldHideItemLabels: Bool
    }
    private struct Name: Encodable { var id: String }
    private struct ChoiceID: Encodable {
        struct Descriptor: Encodable {
            var provider, identifier: String
            var files: [URL]
            var configuration: Data
        }
        var id: String
        var descriptor: Descriptor
    }
    private struct Item: Encodable {
        struct Choice: Encodable {
            var id: ChoiceID
            var provider, identifier, name, localizedDescription: String
            var thumbnail: [String: [String: URL]]
            var isDownloaded: Bool
            var options: [String]
        }
        var id: ChoiceID
        var localizedName: String
        var thumbnail: [String: [String: URL]]
        var choice: Choice
        var contentBadge: [String: [String: String]]
        var showInTopLevel: Bool
        var sortOrder: Int
        var disposability: [String: [String: String]]
    }

    @objc(KeshikiArchivedViewModels)
    private final class Archived: NSObject, NSCoding {
        let value: ViewModels
        init(value: ViewModels) { self.value = value }
        required init?(coder: NSCoder) { nil }
        func encode(with coder: NSCoder) {
            try? (coder as? NSKeyedArchiver)?.encodeEncodable(value, forKey: "WallpaperSettingsViewModels")
        }
    }

    /// Archives our stand-in and decodes it as `WallpaperSettingsViewModelsXPC`. Not secure coding on purpose: the
    /// class swap is the point, and the archive never leaves this function.
    private static func remapToSystemClass(_ archived: Archived) -> AnyObject? {
        guard let systemClass = objc_getClass("WallpaperSettingsViewModelsXPC") as? AnyClass,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: archived, requiringSecureCoding: false),
              let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        unarchiver.setClass(systemClass, forClassName: "KeshikiArchivedViewModels")
        defer { unarchiver.finishDecoding() }
        return unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as AnyObject?
    }
}
