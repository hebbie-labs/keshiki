import AppKit
import WebKit

/// Keeps one pond window on every connected display.
final class PondDisplays {
    private(set) var windows: [PondWindow] = []
    private let memory = PondMemory()
    private let schemeHandler = PondSchemeHandler()
    private let initialSettings: () -> String

    /// `initialSettings` is injected before the page starts, so a pond never flashes the defaults.
    init(initialSettings: @escaping () -> String) {
        self.initialSettings = initialSettings
    }

    var windowNumbers: Set<Int> {
        Set(windows.map(\.windowNumber))
    }

    /// Rebuilding restarts the ponds, so it only happens when the displays really changed.
    func matchConnectedScreens() {
        guard windows.map(\.frame) != NSScreen.screens.map(\.frame) else { return }
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { PondWindow(screen: $0, configuration: makeConfiguration()) }
    }

    func runEverywhere(_ javaScript: String) {
        windows.forEach { $0.run(javaScript) }
    }

    func window(at screenPoint: NSPoint) -> PondWindow? {
        windows.first { $0.frame.contains(screenPoint) }
    }

    private func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: PondSchemeHandler.scheme)
        configuration.userContentController.add(memory, name: PondMemory.messageName)
        let bootstrap = "window.__memory = \(memory.json); window.__settings = \(initialSettings());"
        configuration.userContentController.addUserScript(
            WKUserScript(source: bootstrap, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        return configuration
    }
}
