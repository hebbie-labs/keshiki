import WebKit

/// Stores what the koi learned (feeding routine, last greeting) on behalf of the page.
final class PondMemory: NSObject, WKScriptMessageHandler {
    static let messageName = "save"
    private let defaultsKey = "memory"

    var json: String {
        UserDefaults.standard.string(forKey: defaultsKey) ?? "{}"
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let json = message.body as? String, isValidJSON(json) else { return }
        UserDefaults.standard.set(json, forKey: defaultsKey)
    }

    private func isValidJSON(_ text: String) -> Bool {
        (try? JSONSerialization.jsonObject(with: Data(text.utf8))) != nil
    }
}
