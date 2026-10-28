import AppKit

/// Lifts the ponds above everything until the next key press, click or real mouse move.
final class Screensaver {
    private(set) var isRunning = false
    private var monitors: [Any] = []
    private var startingMousePosition = NSPoint.zero
    private var windows: [PondWindow] = []
    private let onChange: () -> Void

    private let settleDelay: TimeInterval = 1
    private let mouseMoveTolerance: CGFloat = 8
    private let wakeEvents: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown, .mouseMoved, .scrollWheel]

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start(on windows: [PondWindow]) {
        guard !isRunning else { return }
        isRunning = true
        self.windows = windows
        windows.forEach { $0.coverEverything() }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKey()
        NSCursor.hide()
        onChange()
        // Give the menu a moment to close before mouse moves count as "I'm back".
        DispatchQueue.main.asyncAfter(deadline: .now() + settleDelay) { [weak self] in self?.watchForUser() }
    }

    private func watchForUser() {
        startingMousePosition = NSEvent.mouseLocation
        monitors = [
            NSEvent.addLocalMonitorForEvents(matching: wakeEvents) { [weak self] event in
                self?.stopIfUserIsBack(event)
                return nil
            } as Any,
            NSEvent.addGlobalMonitorForEvents(matching: wakeEvents) { [weak self] event in
                self?.stopIfUserIsBack(event)
            } as Any,
        ]
    }

    private func stopIfUserIsBack(_ event: NSEvent) {
        if event.type == .mouseMoved && !mouseMovedNoticeably() { return }
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        isRunning = false
        NSCursor.unhide()
        windows.forEach { $0.sitBehindDesktopIcons() }
        windows = []
        onChange()
    }

    private func mouseMovedNoticeably() -> Bool {
        let now = NSEvent.mouseLocation
        return hypot(now.x - startingMousePosition.x, now.y - startingMousePosition.y) >= mouseMoveTolerance
    }
}
