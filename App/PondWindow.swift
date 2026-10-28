import AppKit
import WebKit

/// A borderless window showing the pond on one display, normally tucked behind the desktop icons.
final class PondWindow: NSWindow, WKNavigationDelegate {
    private let webView: WKWebView

    init(screen: NSScreen, configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: NSRect(origin: .zero, size: screen.frame.size), configuration: configuration)
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        webView.load(URLRequest(url: PondSchemeHandler.pageURL))
        contentView = webView
        setFrame(screen.frame, display: true)
        sitBehindDesktopIcons()
        orderFront(nil)
    }

    /// Borderless windows normally can't become key, but the screensaver needs key presses.
    override var canBecomeKey: Bool { true }

    func sitBehindDesktopIcons() {
        level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
    }

    func coverEverything() {
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = false
        orderFrontRegardless()
    }

    func run(_ javaScript: String) {
        webView.evaluateJavaScript(javaScript)
    }

    /// Converts a screen point (origin bottom-left) into page coordinates (origin top-left).
    func pagePoint(for screenPoint: NSPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - frame.minX, y: frame.maxY - screenPoint.y)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}
