import AppKit

/// Tells whether a click landed on the bare desktop rather than on some app's window.
enum DesktopHitTest {
    static func isDesktop(at screenPoint: NSPoint, ignoring ownWindows: Set<Int>) -> Bool {
        let point = CGPoint(x: screenPoint.x, y: primaryScreenHeight - screenPoint.y)
        let topmost = visibleWindows().first { window in
            !ownWindows.contains(window[kCGWindowNumber as String] as? Int ?? 0)
                && !isInvisibleOverlay(window)
                && bounds(of: window)?.contains(point) == true
        }
        // The desktop (Finder's icon layer, the wallpaper) lives on negative window layers.
        return (topmost?[kCGWindowLayer as String] as? Int ?? 0) < 0
    }

    /// Window-server coordinates start at the top-left of the primary display.
    private static var primaryScreenHeight: CGFloat {
        NSScreen.screens.first?.frame.maxY ?? 0
    }

    private static func visibleWindows() -> [[String: Any]] {
        CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    }

    /// The Window Server keeps a full-screen cursor layer above everything; it never takes clicks.
    private static func isInvisibleOverlay(_ window: [String: Any]) -> Bool {
        window[kCGWindowOwnerName as String] as? String == "Window Server"
            || (window[kCGWindowAlpha as String] as? Double ?? 1) == 0
    }

    private static func bounds(of window: [String: Any]) -> CGRect? {
        guard let dictionary = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: dictionary)
    }
}
