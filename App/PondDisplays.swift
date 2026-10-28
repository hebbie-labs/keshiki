import AppKit

/// Keeps one pond window on every connected display.
final class PondDisplays {
    private(set) var windows: [PondWindow] = []

    var windowNumbers: Set<Int> {
        Set(windows.map(\.windowNumber))
    }

    var scenes: [PondScene] {
        windows.map(\.scene)
    }

    /// Rebuilding starts fresh ponds, so it only happens when the displays really changed.
    func matchConnectedScreens(settings: PondSettings) {
        guard windows.map(\.frame) != NSScreen.screens.map(\.frame) else { return }
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { PondWindow(screen: $0, settings: settings) }
    }

    /// Moves every pond forward; only draws the ones someone can see.
    func advance(by dt: Double, drawHiddenPonds: Bool) {
        for window in windows {
            window.scene.advance(by: dt)
            if drawHiddenPonds || window.isShowing { window.drawNextFrame() }
        }
    }

    func window(at screenPoint: NSPoint) -> PondWindow? {
        windows.first { $0.frame.contains(screenPoint) }
    }
}
