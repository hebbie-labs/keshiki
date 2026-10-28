import UniformTypeIdentifiers
import WebKit

/// Serves the bundled pond page over pond:// — WebKit refuses ES modules from file:// URLs.
final class PondSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "pond"
    static let pageURL = URL(string: "pond://app/index.html")!

    private let root = Bundle.main.resourceURL!.appendingPathComponent("Pond").standardizedFileURL

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let data = contents(of: url) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mimeType = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mimeType, expectedContentLength: data.count, textEncodingName: "utf-8"))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    /// Only files inside the bundled Pond folder are served.
    private func contents(of url: URL) -> Data? {
        let file = root.appendingPathComponent(url.path).standardizedFileURL
        guard file.path.hasPrefix(root.path + "/") else { return nil }
        return try? Data(contentsOf: file)
    }
}
