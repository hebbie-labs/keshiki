import AppKit

/// Wires the ponds, the menu bar, desktop clicks, the screensaver and the lock screen together.
final class PondController: NSObject, NSApplicationDelegate {
    var settings = PondSettings.load() {
        didSet { settingsChanged(from: oldValue) }
    }

    private let displays = PondDisplays()
    private let memory = MemoryStore()
    private let screensaver = Screensaver()
    private let lockScreen = LockScreenWallpaper()
    private var statusMenu: StatusMenu?
    private var lastFrame = Date()
    private var onBattery = SystemConditions.isOnBattery

    private static let framesPerSecond = 30.0
    private static let longestFrame = 0.1
    private static let routineCheckInterval: TimeInterval = 30
    private static let lockScreenRefreshInterval: TimeInterval = 15 * 60
    private static let greetingSeconds: TimeInterval = 12

    func applicationDidFinishLaunching(_ notification: Notification) {
        displays.matchConnectedScreens(settings: settings)
        applySystemAppearance()
        statusMenu = StatusMenu(controller: self)
        observeSystem()
        repeatEvery(1 / Self.framesPerSecond) { [unowned self] in drawFrame() }
        repeatEvery(Self.routineCheckInterval, startNow: true) { [unowned self] in checkRoutine() }
        repeatEvery(Self.lockScreenRefreshInterval, startNow: true) { [unowned self] in refreshLockScreen() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        lockScreen.restoreOriginals()
    }

    func invite(_ visitor: Visitor) {
        displays.scenes.forEach { $0.world.invite(visitor) }
    }

    func startScreensaver() {
        screensaver.start(on: displays.windows)
    }

    func installScreensaver() {
        guard let saver = Bundle.main.url(forResource: "Wallpapers", withExtension: "saver") else { return }
        NSWorkspace.shared.open(saver)
    }

    // MARK: - Frames

    private var isResting: Bool {
        settings.paused || (settings.restOnBattery && onBattery && !screensaver.isRunning)
    }

    private func drawFrame() {
        let now = Date()
        let dt = min(Self.longestFrame, now.timeIntervalSince(lastFrame))
        lastFrame = now
        guard !isResting else { return }
        displays.advance(by: dt, drawHiddenPonds: screensaver.isRunning)
    }

    // MARK: - Settings and system

    private func settingsChanged(from old: PondSettings) {
        settings.save()
        displays.scenes.forEach { $0.settings = settings }
        if settings.theme != old.theme || settings.water != old.water || settings.lockScreenPond != old.lockScreenPond {
            refreshLockScreen()
        }
    }

    private func observeSystem() {
        let center = NotificationCenter.default, distributed = DistributedNotificationCenter.default()
        center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [unowned self] _ in
            displays.matchConnectedScreens(settings: settings)
        }
        distributed.addObserver(forName: .init("AppleInterfaceThemeChangedNotification"), object: nil, queue: .main) { [unowned self] _ in
            applySystemAppearance()
        }
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [unowned self] _ in
            refreshLockScreen()
        }
        NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [unowned self] event in forwardDesktopClick(event) }
    }

    private func applySystemAppearance() {
        let dark = SystemConditions.isDarkMode
        displays.scenes.forEach { $0.systemDark = dark }
        onBattery = SystemConditions.isOnBattery
    }

    private func refreshLockScreen() {
        onBattery = SystemConditions.isOnBattery
        if settings.lockScreenPond { lockScreen.show(displays.windows) } else { lockScreen.restoreOriginals() }
    }

    // MARK: - Clicks and routine

    /// The desktop belongs to Finder, so clicks never reach our windows; we watch them and pass them on.
    private func forwardDesktopClick(_ event: NSEvent) {
        guard !screensaver.isRunning else { return }
        let location = NSEvent.mouseLocation
        guard let window = displays.window(at: location),
              DesktopHitTest.isDesktop(at: location, ignoring: displays.windowNumbers) else { return }
        let spot = window.normalizedPoint(for: location)
        let point = window.scene.pondPoint(fromNormalized: spot)
        if !event.modifierFlags.contains(.option) {
            window.scene.world.touchWater(at: point)
        } else if settings.feedOnAlt {
            window.scene.world.dropFood(at: point)
            memory.recordFeeding(at: spot, on: Date())
        }
    }

    /// The koi wait at your usual feeding spot, and greet you the first time you see them each day.
    private func checkRoutine() {
        let now = Date()
        let usualSpot = memory.usualSpot(at: now)
        displays.scenes.forEach { scene in scene.world.usualSpot = usualSpot.map { scene.pondPoint(fromNormalized: $0) } }
        guard !isResting, memory.claimDailyGreeting(on: now) else { return }
        let spot = usualSpot ?? memory.lastFeedingSpot ?? Point(x: 0.5, y: 0.5)
        for window in displays.windows {
            window.scene.world.gather(at: window.scene.pondPoint(fromNormalized: spot))
            window.greet(at: spot)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.greetingSeconds) { [unowned self] in
            displays.scenes.forEach { $0.world.scatter() }
        }
    }

    private func repeatEvery(_ interval: TimeInterval, startNow: Bool = false, _ action: @escaping () -> Void) {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in action() }
        RunLoop.main.add(timer, forMode: .common)
        if startNow { DispatchQueue.main.async(execute: action) }
    }
}
