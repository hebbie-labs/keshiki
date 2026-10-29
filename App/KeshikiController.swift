import AppKit

/// Wires the scenes, the menu bar, desktop clicks, the screensaver and the lock screen together.
final class KeshikiController: NSObject, NSApplicationDelegate {
    var settings = SettingsStore.load(SettingsStore.generalKey, default: KeshikiSettings()) {
        didSet { settingsChanged(from: oldValue) }
    }

    private let displays = SceneDisplays()
    private let screensaver = Screensaver()
    private let lockScreen = LockScreenWallpaper()
    private let appWindows = WindowWatcher()
    private var controls: SceneControls?
    private var controlsKind: SceneKind?
    private var statusMenu: StatusMenu?
    private var lastFrame = Date()
    private var onBattery = SystemConditions.isOnBattery

    private static let framesPerSecond = 30.0
    private static let longestFrame = 0.1
    private static let checkInInterval: TimeInterval = 30
    private static let lockScreenRefreshInterval: TimeInterval = 15 * 60

    func applicationDidFinishLaunching(_ notification: Notification) {
        showChosenScene()
        statusMenu = StatusMenu(controller: self)
        observeSystem()
        repeatEvery(1 / Self.framesPerSecond) { [unowned self] in drawFrame() }
        repeatEvery(Self.checkInInterval, startNow: true) { [unowned self] in
            controls?.checkIn(windows: displays.windows, isResting: isResting)
        }
        repeatEvery(Self.lockScreenRefreshInterval, startNow: true) { [unowned self] in refreshLockScreen() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lockScreen.restoreOriginals()
    }

    /// The menu section of the scene that's showing.
    var sceneMenuItems: [NSMenuItem] {
        controls?.menuItems() ?? []
    }

    func startScreensaver() {
        screensaver.start(on: displays.windows)
    }

    /// macOS 26+: the wallpaper extension plays the scene on the lock screen once it's picked in System Settings.
    func openWallpaperSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension")!)
    }

    func installScreensaver() {
        guard let saver = Bundle.main.url(forResource: "Keshiki", withExtension: "saver") else { return }
        NSWorkspace.shared.open(saver)
    }

    // MARK: - Frames

    private var isResting: Bool {
        settings.paused || (settings.restOnBattery && onBattery && !screensaver.isRunning)
    }

    /// A display's scene runs only while its desktop is free: no app window open on it and not covered.
    private func shouldRun(_ window: SceneWindow) -> Bool {
        screensaver.isRunning || (window.isShowing && !appWindows.hasWindows(on: window.frame))
    }

    private func drawFrame() {
        let now = Date()
        let dt = min(Self.longestFrame, now.timeIntervalSince(lastFrame))
        lastFrame = now
        guard !isResting else { return }
        displays.advance(by: dt, where: shouldRun)
    }

    // MARK: - Settings and system

    private func showChosenScene() {
        if settings.scene != controlsKind {
            controls = settings.scene.makeControls { [unowned self] in displays.scenes }
            controlsKind = settings.scene
        }
        displays.show(settings.scene, settings: settings) { [unowned self] scene in
            scene.systemDark = SystemConditions.isDarkMode
            controls?.configure(scene)
        }
    }

    private func settingsChanged(from old: KeshikiSettings) {
        SettingsStore.save(settings, as: SettingsStore.generalKey)
        if settings.scene != old.scene { showChosenScene() }
        displays.scenes.forEach { $0.settings = settings }
        if settings.scene != old.scene || settings.theme != old.theme || settings.showOnLockScreen != old.showOnLockScreen {
            refreshLockScreen()
        }
    }

    private func observeSystem() {
        let center = NotificationCenter.default, distributed = DistributedNotificationCenter.default()
        center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [unowned self] _ in
            showChosenScene()
        }
        distributed.addObserver(forName: .init("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main) { [unowned self] _ in
            let dark = SystemConditions.isDarkMode
            displays.scenes.forEach { $0.systemDark = dark }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [unowned self] _ in
            refreshLockScreen()
        }
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [unowned self] event in forwardDesktopClick(event) }
    }

    private func refreshLockScreen() {
        onBattery = SystemConditions.isOnBattery
        if settings.showOnLockScreen { lockScreen.show(displays.windows) } else { lockScreen.restoreOriginals() }
    }

    /// The desktop belongs to Finder, so clicks never reach our windows; we watch them and pass them on.
    /// A click may also have closed or moved a window, so the window watcher looks again.
    private func forwardDesktopClick(_ event: NSEvent) {
        appWindows.refresh()
        guard !screensaver.isRunning else { return }
        let location = NSEvent.mouseLocation
        guard let window = displays.window(at: location),
              DesktopHitTest.isDesktop(at: location, ignoring: displays.windowNumbers) else { return }
        window.scene.touch(at: window.normalizedPoint(for: location), withOption: event.modifierFlags.contains(.option))
    }

    /// A little tolerance lets macOS fire the timer together with other wake-ups, which saves energy.
    private func repeatEvery(_ interval: TimeInterval, startNow: Bool = false, _ action: @escaping () -> Void) {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        if startNow { DispatchQueue.main.async(execute: action) }
    }
}
