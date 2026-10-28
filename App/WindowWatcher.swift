import AppKit

/// Knows which displays have app windows open on them, so the scene there rests while you work.
/// A display counts as busy as soon as any window of another app lies on it, focused or not.
final class WindowWatcher {
    private(set) var busyDisplays: [CGRect] = []

    private static let recheckInterval: TimeInterval = 1
    /// Smaller windows are usually helpers (tooltips, status windows), not something you work in.
    private static let minimumSide: CGFloat = 40

    init() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        }
        // Windows open, close and move without any notification.
        let timer = Timer(timeInterval: Self.recheckInterval, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    /// True if any app window lies on the display with this frame (screen coordinates).
    func hasWindows(on screenFrame: CGRect) -> Bool {
        busyDisplays.contains(screenFrame)
    }

    func refresh() {
        let screens = NSScreen.screens.map(\.frame)
        let primaryHeight = screens.first?.maxY ?? 0
        let windows = appWindowBounds()
        busyDisplays = screens.filter { screen in windows.contains { $0.intersects(Self.flipped(screen, primaryHeight)) } }
    }

    /// Normal windows of other apps that are on screen in the current Spaces, in top-left origin coordinates.
    private func appWindowBounds() -> [CGRect] {
        let ownProcess = getpid()
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.compactMap { window in
            guard window[kCGWindowLayer as String] as? Int == 0,
                  window[kCGWindowOwnerPID as String] as? pid_t != ownProcess,
                  (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
                  let dictionary = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dictionary),
                  bounds.width >= Self.minimumSide, bounds.height >= Self.minimumSide else { return nil }
            return bounds
        }
    }

    /// Screen frames start at the bottom left; window bounds at the top left of the primary display.
    private static func flipped(_ screen: CGRect, _ primaryHeight: CGFloat) -> CGRect {
        CGRect(x: screen.minX, y: primaryHeight - screen.maxY, width: screen.width, height: screen.height)
    }
}
