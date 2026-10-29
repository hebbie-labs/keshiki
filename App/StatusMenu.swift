import AppKit

/// The 鯉 menu in the menu bar. It's rebuilt each time it opens, so it always matches the current scene.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private unowned let controller: KeshikiController

    private let timesOfDay = [("dawn", "Dawn"), ("day", "Day"), ("golden", "Golden Hour"), ("dusk", "Dusk"), ("night", "Night")]

    init(controller: KeshikiController) {
        self.controller = controller
        super.init()
        statusItem.button?.title = "鯉"
        statusItem.button?.toolTip = "Keshiki"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.items = generalItems() + [.separator()] + controller.sceneMenuItems + [.separator()] + appItems()
    }

    private var binding: MenuBinding<KeshikiSettings> {
        MenuBinding(get: { [unowned controller] in controller.settings }, set: { [unowned controller] in controller.settings = $0 })
    }

    private func generalItems() -> [NSMenuItem] {
        let header = NSMenuItem(title: headerTitle(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        return [
            header,
            .separator(),
            submenu("Scene", SceneKind.allCases.map { binding.choice($0.title, \.scene, $0) }),
            submenu("Theme", themeItems()),
            binding.toggle("Rain", \.rain),
            binding.toggle("Pause Wallpaper", \.paused),
            MenuEntry("Start Screensaver") { [unowned controller] in controller.startScreensaver() },
        ]
    }

    private func appItems() -> [NSMenuItem] {
        var lockScreen = [binding.toggle("Show on Lock Screen", \.showOnLockScreen)]
        if #available(macOS 26, *) {
            lockScreen.append(MenuEntry("Animate Lock Screen…") { [unowned controller] in controller.openWallpaperSettings() })
        }
        let pauseWhen = submenu("Pause When", [
            binding.choice("Any Window Is Open", \.pauseWhen, "window"),
            binding.choice("An App Is Fullscreen", \.pauseWhen, "fullscreen"),
            binding.choice("Never", \.pauseWhen, "never"),
        ])
        return [pauseWhen, binding.toggle("Rest on Battery", \.restOnBattery)] + lockScreen + [
            MenuEntry("Install Screensaver…") { [unowned controller] in controller.installScreensaver() },
            .separator(),
            NSMenuItem(title: "Quit Keshiki", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"),
        ]
    }

    private func themeItems() -> [NSMenuItem] {
        [binding.choice("Sync Theme with Time", \.theme, "time"), binding.choice("Sync Theme with System", \.theme, "system"), .separator()]
            + timesOfDay.map { binding.choice($0.1, \.theme, $0.0) }
    }

    private func headerTitle() -> String {
        "Keshiki · \(controller.settings.scene.title)" + (controller.settings.paused ? " (paused)" : "")
    }
}
