import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Apps can't draw on the lock screen, but the lock screen shows the desktop picture.
/// So a still of each scene becomes the desktop picture, and the user's own pictures come back on quit.
final class LockScreenWallpaper {
    private static let originalsKey = SettingsStore.originalDesktopPicturesKey
    private let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Keshiki/LockScreen", isDirectory: true)

    func show(_ windows: [SceneWindow]) {
        rememberOriginals()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // A new file name every time; macOS caches pictures by URL.
        let stamp = Int(Date().timeIntervalSince1970)
        var current: Set<URL> = []
        for window in windows {
            guard let screen = window.screen, let image = window.snapshot(), let id = screen.displayID else { continue }
            let url = folder.appendingPathComponent("scene-\(id)-\(stamp).png")
            guard write(image, scaledToFill: screen, to: url) else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
            current.insert(url)
        }
        deleteSnapshots(except: current)
    }

    func restoreOriginals() {
        guard let originals = UserDefaults.standard.dictionary(forKey: Self.originalsKey) as? [String: String] else { return }
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let path = originals[String(id)] else { continue }
            try? NSWorkspace.shared.setDesktopImageURL(URL(fileURLWithPath: path), for: screen, options: [:])
        }
        UserDefaults.standard.removeObject(forKey: Self.originalsKey)
        deleteSnapshots(except: [])
    }

    /// Only the first time; after a crash the saved originals are still the user's own.
    private func rememberOriginals() {
        guard UserDefaults.standard.dictionary(forKey: Self.originalsKey) == nil else { return }
        var originals: [String: String] = [:]
        for screen in NSScreen.screens {
            guard let id = screen.displayID, let url = NSWorkspace.shared.desktopImageURL(for: screen) else { continue }
            originals[String(id)] = url.path
        }
        UserDefaults.standard.set(originals, forKey: Self.originalsKey)
    }

    /// Scales up by a whole number with nearest-neighbour, so the pixels stay crisp.
    private func write(_ image: CGImage, scaledToFill screen: NSScreen, to url: URL) -> Bool {
        let factor = max(1, Int((screen.frame.width * screen.backingScaleFactor / CGFloat(image.width)).rounded(.up)))
        let width = image.width * factor, height = image.height * factor
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return false }
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let scaled = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, scaled, nil)
        return CGImageDestinationFinalize(destination)
    }

    private func deleteSnapshots(except keep: Set<URL>) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        for file in files where !keep.contains(file) { try? FileManager.default.removeItem(at: file) }
    }
}

private extension NSScreen {
    var displayID: UInt32? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
