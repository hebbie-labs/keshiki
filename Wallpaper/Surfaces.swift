import AppKit
import IOSurface
import Metal

/// Every place the system shows our wallpaper (a desktop Space, the lock screen, a preview in System Settings), each
/// with its own scene, drawn into a layer the WallpaperAgent hosts from our process. Main thread only.
final class Surfaces {
    static let shared = Surfaces()

    private final class Surface {
        let context: CAContext
        let layer = CAMetalLayer()
        var stage: WaterStage?
        var size: CGSize
        var animates: Bool
        var teardown: DispatchWorkItem?

        init(context: CAContext, size: CGSize, animates: Bool) {
            self.context = context
            self.size = size
            self.animates = animates
        }
    }

    private var surfaces: [UUID: Surface] = [:]
    private var settings = SharedSettings.fromApp()
    private var lastFrame = Date()

    private static let framesPerSecond = 30.0
    private static let longestFrame = 0.1
    /// A pick in System Settings drops a surface and asks for it again a moment later; keeping it that long avoids a
    /// grey flash.
    private static let teardownGrace: TimeInterval = 5

    func start() {
        let timer = Timer(timeInterval: 1 / Self.framesPerSecond, repeats: true) { [unowned self] _ in drawFrame() }
        timer.tolerance = 0.2 / Self.framesPerSecond
        RunLoop.main.add(timer, forMode: .common)
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, { _, observer, _, _, _ in
            guard let observer else { return }
            let surfaces = Unmanaged<Surfaces>.fromOpaque(observer).takeUnretainedValue()
            DispatchQueue.main.async { surfaces.settingsChanged() }
        }, SharedSettings.changedNotification as CFString, nil, .deliverImmediately)
    }

    /// Shows the wallpaper on the surface `id` and returns the id of the layer tree the agent should host.
    func acquire(_ id: UUID, size: CGSize, scale: CGFloat, display: UInt32?, animates: Bool) -> UInt32? {
        if let surface = surfaces[id] {
            surface.teardown?.cancel()
            surface.animates = animates
            if surface.size != size {
                surface.size = size
                layOut(surface, scale: scale)
            }
            return surface.context.contextId
        }
        let options: [String: Any] = display.map { ["displayId": $0] } ?? [:]
        guard let context = CAContext.remoteContext(withOptions: options) as? CAContext, context.contextId != 0 else { return nil }
        let surface = Surface(context: context, size: size, animates: animates)
        context.layer = surface.layer
        surfaces[id] = surface
        layOut(surface, scale: scale)
        return context.contextId
    }

    /// The agent says whether a surface is on screen, and whether it's the desktop or the lock screen / screensaver.
    func update(_ id: UUID, animates: Bool) {
        surfaces[id]?.animates = animates
    }

    func invalidate(_ id: UUID) {
        guard let surface = surfaces[id] else { return }
        let teardown = DispatchWorkItem { [weak self] in self?.surfaces[id] = nil }
        surface.teardown = teardown
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.teardownGrace, execute: teardown)
    }

    /// A still for the agent's transitions, in an IOSurface as the agent wants it.
    func snapshot() -> IOSurface? {
        let shown = surfaces.values.first { $0.stage != nil }
        let size = shown?.layer.drawableSize ?? CGSize(width: 1440, height: 900)
        let aspect = size.width / size.height
        guard let stage = shown?.stage ?? WaterStage(scene: settings.makeScene(aspectRatio: WaterStage.pondAspect(screenAspect: aspect)), screenAspect: aspect),
              let device = SceneRenderer.device else { return nil }
        let width = Int(size.width), height = Int(size.height)
        guard let surface = IOSurface(properties: [.width: width, .height: height, .bytesPerElement: 4, .pixelFormat: 0x4247_5241]) else { return nil } // 'BGRA'
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: WaterStage.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget]
        guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else { return nil }
        var finished: MTLCommandBuffer?
        stage.render(into: texture, simulate: false) { finished = $0 }
        finished?.waitUntilCompleted()
        return surface
    }

    /// The picture on the tile in System Settings.
    /// System Settings keeps the URL it got, so a fresh one overwrites the file in place instead of removing it.
    func thumbnail(fresh: Bool = false) -> URL? {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Caches/koi-pond.png")
        if !fresh, FileManager.default.fileExists(atPath: url.path) { return url }
        let aspect = 16.0 / 10
        guard let stage = WaterStage(scene: settings.makeScene(aspectRatio: WaterStage.pondAspect(screenAspect: aspect)), screenAspect: aspect) else { return nil }
        for _ in 0..<60 { stage.scene.advance(by: 1 / Self.framesPerSecond) }
        guard let image = stage.snapshot(width: 480, height: 300),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return nil }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? png.write(to: url, options: .atomic)) == nil ? nil : url
    }

    /// A new stage in the surface's shape, with a first frame drawn before the agent shows it.
    private func layOut(_ surface: Surface, scale: CGFloat) {
        let aspect = surface.size.width / max(surface.size.height, 1)
        let scene = settings.makeScene(aspectRatio: WaterStage.pondAspect(screenAspect: aspect))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        surface.layer.frame = CGRect(origin: .zero, size: surface.size)
        surface.layer.contentsScale = scale
        WaterStage.configure(surface.layer, width: scene.pixelWidth, height: Int((Double(scene.pixelWidth) / aspect).rounded()))
        CATransaction.commit()
        surface.stage = WaterStage(scene: scene, screenAspect: aspect)
        draw(surface)
        CATransaction.flush()
    }

    private func settingsChanged() {
        settings = SharedSettings.fromApp()
        _ = thumbnail(fresh: true)
        for surface in surfaces.values {
            layOut(surface, scale: surface.layer.contentsScale)
        }
    }

    private func drawFrame() {
        let now = Date()
        let dt = min(Self.longestFrame, now.timeIntervalSince(lastFrame))
        lastFrame = now
        guard !settings.general.paused else { return }
        for surface in surfaces.values where surface.animates {
            surface.stage?.scene.advance(by: dt)
            draw(surface)
        }
    }

    private func draw(_ surface: Surface) {
        guard let stage = surface.stage, let drawable = surface.layer.nextDrawable() else { return }
        stage.render(into: drawable.texture) { $0.present(drawable) }
    }
}
