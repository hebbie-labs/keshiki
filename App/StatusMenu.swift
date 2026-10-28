import AppKit

/// The 鯉 menu in the menu bar.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private unowned let controller: PondController

    private let timesOfDay = [("dawn", "Dawn"), ("day", "Day"), ("golden", "Golden Hour"), ("dusk", "Dusk"), ("night", "Night")]

    init(controller: PondController) {
        self.controller = controller
        super.init()
        statusItem.button?.title = "鯉"
        statusItem.button?.toolTip = "Koi Pond"
        statusItem.menu = buildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        header.title = headerTitle()
        refreshCheckmarks(in: menu)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        header.isEnabled = false
        menu.items = [
            header,
            .separator(),
            toggle("Pause Wallpaper", \.paused),
            MenuEntry("Start Screensaver") { [unowned controller] in controller.startScreensaver() },
            .separator(),
            submenu("Theme", themeItems()),
            toggle("Rain", \.rain),
            submenu("Koi Mood", [choice("Calm", \.mood, "calm"), choice("Playful", \.mood, "playful")]),
            submenu("Visitors", visitorItems()),
            .separator(),
            toggle("Call Fish on Click", \.callOnClick),
            toggle("Feed Koi with ⌥-Click", \.feedOnAlt),
            toggle("Rest on Battery", \.restOnBattery),
            .separator(),
            toggle("Show Pond on Lock Screen", \.lockScreenPond),
            MenuEntry("Install Screensaver…") { [unowned controller] in controller.installScreensaver() },
            .separator(),
            NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ]
        return menu
    }

    private func themeItems() -> [NSMenuItem] {
        let otherThemes = [choice("Koi Pond", \.water, "pond"), choice("Deep Clear", \.water, "deep-clear")]
        return [choice("Sync Theme with Time", \.theme, "time"), choice("Sync Theme with System", \.theme, "system"), .separator()]
            + timesOfDay.map { choice($0.1, \.theme, $0.0) }
            + [.separator(), submenu("Other Themes", otherThemes)]
    }

    private func visitorItems() -> [NSMenuItem] {
        [
            MenuEntry("Invite the Goose") { [unowned controller] in controller.invite(.goose) },
            MenuEntry("Drop a Temari Ball") { [unowned controller] in controller.invite(.ball) },
            .separator(),
            MenuEntry("Clear Visitors") { [unowned controller] in controller.invite(.clear) },
        ]
    }

    private func toggle(_ title: String, _ setting: WritableKeyPath<PondSettings, Bool>) -> MenuEntry {
        MenuEntry(title, isOn: { [unowned controller] in controller.settings[keyPath: setting] }) { [unowned controller] in
            controller.settings[keyPath: setting].toggle()
        }
    }

    private func choice(_ title: String, _ setting: WritableKeyPath<PondSettings, String>, _ value: String) -> MenuEntry {
        MenuEntry(title, isOn: { [unowned controller] in controller.settings[keyPath: setting] == value }) { [unowned controller] in
            controller.settings[keyPath: setting] = value
        }
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = NSMenu()
        item.submenu?.items = items
        return item
    }

    private func headerTitle() -> String {
        let theme = controller.settings.theme
        let label = theme == "time" ? "Synced with Time"
            : theme == "system" ? "Synced with System"
            : timesOfDay.first { $0.0 == theme }?.1 ?? theme
        return "Koi Pond · \(label)" + (controller.settings.paused ? " (paused)" : "")
    }

    private func refreshCheckmarks(in menu: NSMenu) {
        for item in menu.items {
            (item as? MenuEntry)?.refreshCheckmark()
            if let submenu = item.submenu { refreshCheckmarks(in: submenu) }
        }
    }
}
