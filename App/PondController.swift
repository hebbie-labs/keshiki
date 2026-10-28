import AppKit

/// Wires the pond windows, the menu bar, desktop clicks and the screensaver together.
final class PondController: NSObject, NSApplicationDelegate {
    var settings = PondSettings.load() {
        didSet {
            settings.save()
            sendSettingsToPonds()
        }
    }

    private lazy var displays = PondDisplays { [unowned self] in pondSettingsObject() }
    private lazy var screensaver = Screensaver { [unowned self] in sendSettingsToPonds() }
    private var statusMenu: StatusMenu?

    private let batteryCheckInterval: TimeInterval = 30

    func applicationDidFinishLaunching(_ notification: Notification) {
        displays.matchConnectedScreens()
        statusMenu = StatusMenu(controller: self)
        observeSystem()
    }

    func invite(_ visitor: String) {
        displays.runEverywhere("pond.visit('\(visitor)')")
    }

    func startScreensaver() {
        screensaver.start(on: displays.windows)
    }

    private func observeSystem() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [unowned self] _ in displays.matchConnectedScreens() }

        DistributedNotificationCenter.default().addObserver(
            forName: .init("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main
        ) { [unowned self] _ in sendSettingsToPonds() }

        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [unowned self] event in forwardDesktopClick(event) }

        Timer.scheduledTimer(withTimeInterval: batteryCheckInterval, repeats: true) { [unowned self] _ in sendSettingsToPonds() }
    }

    private func sendSettingsToPonds() {
        displays.runEverywhere("window.pond && pond.set(\(pondSettingsObject()))")
    }

    private func pondSettingsObject() -> String {
        let resting = settings.restOnBattery && SystemConditions.isOnBattery && !screensaver.isRunning
        return settings.javaScriptObject(paused: settings.paused || resting, systemDark: SystemConditions.isDarkMode)
    }

    /// The desktop belongs to Finder, so clicks never reach our windows; we watch them and pass them on.
    private func forwardDesktopClick(_ event: NSEvent) {
        guard !screensaver.isRunning else { return }
        let location = NSEvent.mouseLocation
        guard let window = displays.window(at: location),
              DesktopHitTest.isDesktop(at: location, ignoring: displays.windowNumbers) else { return }
        let point = window.pagePoint(for: location)
        window.run("pond.click(\(point.x), \(point.y), \(event.modifierFlags.contains(.option)))")
    }
}
