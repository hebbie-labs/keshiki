import CoreGraphics
import Metal
import QuartzCore

/// Draws a scene on the GPU: its backdrop (with the light net), then every recorded shape as an instanced quad.
/// One renderer per display; the device, pipelines and caustics tile are shared.
final class SceneRenderer {
    private struct Shared {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let shapes: MTLRenderPipelineState
        let backdrop: MTLRenderPipelineState
        let overlay: MTLRenderPipelineState
        let caustics: MTLTexture

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
                  let library = try? device.makeLibrary(source: Shaders.source, options: nil) else { return nil }
            func pipeline(_ vertex: String, _ fragment: String, blending: Bool) -> MTLRenderPipelineState? {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: vertex)
                descriptor.fragmentFunction = library.makeFunction(name: fragment)
                let attachment = descriptor.colorAttachments[0]!
                attachment.pixelFormat = SceneRenderer.pixelFormat
                attachment.isBlendingEnabled = blending
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                return try? device.makeRenderPipelineState(descriptor: descriptor)
            }
            guard let shapes = pipeline("shapeVertex", "shapeFragment", blending: true),
                  let backdrop = pipeline("fullScreenVertex", "backdropFragment", blending: false),
                  let overlay = pipeline("fullScreenVertex", "overlayFragment", blending: true),
                  let caustics = Self.uploadCaustics(to: device) else { return nil }
            self.device = device
            self.queue = queue
            self.shapes = shapes
            self.backdrop = backdrop
            self.overlay = overlay
            self.caustics = caustics
        }

        private static func uploadCaustics(to device: MTLDevice) -> MTLTexture? {
            let tile = Caustics.makeTile()
            let descriptor = MTLTextureDescriptor()
            descriptor.textureType = .type2DArray
            descriptor.pixelFormat = .r8Unorm
            descriptor.width = tile.size
            descriptor.height = tile.size
            descriptor.arrayLength = tile.frames.count
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
            for (index, frame) in tile.frames.enumerated() {
                frame.withUnsafeBytes { bytes in
                    texture.replace(region: MTLRegionMake2D(0, 0, tile.size, tile.size), mipmapLevel: 0, slice: index,
                                    withBytes: bytes.baseAddress!, bytesPerRow: tile.size, bytesPerImage: tile.size * tile.size)
                }
            }
            return texture
        }
    }

    /// One display's share of a frame.
    struct Job {
        let renderer: SceneRenderer
        let scene: LivingScene
        let layer: CAMetalLayer
    }

    static let pixelFormat = MTLPixelFormat.bgra8Unorm
    private static let shared = Shared()
    /// Two frames in flight at most: one being drawn by the GPU, one being recorded.
    private static let framesInFlight = 2
    private static let inFlight = DispatchSemaphore(value: framesInFlight)

    private let shared: Shared
    private let drawList: DrawList
    private var backdropTexture: MTLTexture?
    private var overlay: (indices: MTLTexture, palette: [SIMD4<Float>])?
    private var shapeBuffers: [MTLBuffer?] = Array(repeating: nil, count: framesInFlight)
    private var bufferIndex = 0

    static var isAvailable: Bool { shared != nil }

    static func configure(_ layer: CAMetalLayer, width: Int, height: Int) {
        layer.device = shared?.device
        layer.pixelFormat = pixelFormat
        layer.framebufferOnly = true
        layer.maximumDrawableCount = 2
        layer.drawableSize = CGSize(width: width, height: height)
        layer.magnificationFilter = .nearest
        layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        layer.isOpaque = true
    }

    /// Uploads the scene's painted layers right away, so their CPU copies are freed
    /// even on a display that stays paused and never draws.
    init?(scene: LivingScene) {
        guard let shared = Self.shared else { return nil }
        self.shared = shared
        drawList = DrawList(width: scene.pixelWidth, height: scene.pixelHeight, scale: scene.pixelScale)
        uploadNewLayers(of: scene)
    }

    /// Draws the next frame of every job into its layer, all in one GPU submission: each submission
    /// costs a trip into the kernel, so three displays share one instead of paying three times.
    static func render(_ jobs: [Job], at date: Date = Date(), completion: ((MTLCommandBuffer) -> Void)? = nil) {
        guard !jobs.isEmpty, let shared, let commands = shared.queue.makeCommandBuffer() else { return }
        inFlight.wait()
        for job in jobs {
            guard let drawable = job.layer.nextDrawable() else { continue }
            job.renderer.encode(job.scene, into: drawable.texture, at: date, commands: commands)
            commands.present(drawable)
        }
        commands.addCompletedHandler { buffer in
            completion?(buffer)
            inFlight.signal()
        }
        commands.commit()
    }

    /// A still of the scene's current frame, e.g. for the lock screen.
    func snapshot(_ scene: LivingScene, at date: Date = Date()) -> CGImage? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: scene.pixelWidth,
                                                                  height: scene.pixelHeight, mipmapped: false)
        descriptor.usage = .renderTarget
        descriptor.storageMode = .shared
        Self.inFlight.wait()
        defer { Self.inFlight.signal() }
        guard let texture = shared.device.makeTexture(descriptor: descriptor), let commands = shared.queue.makeCommandBuffer() else { return nil }
        encode(scene, into: texture, at: date, commands: commands)
        commands.commit()
        commands.waitUntilCompleted()
        let image = PixelBuffer(width: texture.width, height: texture.height)
        image.pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return image.makeImage()
    }

    private func encode(_ scene: LivingScene, into target: MTLTexture, at date: Date, commands: MTLCommandBuffer) {
        uploadNewLayers(of: scene)
        drawList.reset()
        scene.draw(on: drawList, at: date)
        guard let backdropTexture, let shapes = shapeBuffer(for: drawList.primitives) else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        drawBackdrop(backdropTexture, caustics: scene.caustics, scale: scene.pixelScale, with: encoder)
        let count = drawList.primitives.count
        if let overlay, let split = drawList.overlayIndex {
            drawShapes(shapes, range: 0..<split, size: target, with: encoder)
            drawOverlay(overlay.indices, palette: overlay.palette, with: encoder)
            drawShapes(shapes, range: split..<count, size: target, with: encoder)
        } else {
            drawShapes(shapes, range: 0..<count, size: target, with: encoder)
        }
        encoder.endEncoding()
    }

    private func drawBackdrop(_ texture: MTLTexture, caustics: CausticsFrame?, scale: Double, with encoder: MTLRenderCommandEncoder) {
        let light = Caustics.light
        var uniforms = (
            SIMD4<Float>(Float(caustics?.driftX ?? 0), Float(caustics?.driftY ?? 0), Float(scale), Float(caustics?.index ?? 0)),
            SIMD4<Float>(Float(light.red) / 255, Float(light.green) / 255, Float(light.blue) / 255, caustics == nil ? 0 : 1)
        )
        encoder.setRenderPipelineState(shared.backdrop)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.setFragmentTexture(shared.caustics, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func drawOverlay(_ texture: MTLTexture, palette: [SIMD4<Float>], with encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(shared.overlay)
        encoder.setFragmentTexture(texture, index: 0)
        palette.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func drawShapes(_ buffer: MTLBuffer, range: Range<Int>, size: MTLTexture, with encoder: MTLRenderCommandEncoder) {
        guard !range.isEmpty else { return }
        var viewport = SIMD2<Float>(Float(size.width), Float(size.height))
        encoder.setRenderPipelineState(shared.shapes)
        encoder.setVertexBuffer(buffer, offset: 0, index: 0)
        encoder.setVertexBytes(&viewport, length: MemoryLayout<SIMD2<Float>>.size, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: range.count, baseInstance: range.lowerBound)
    }

    /// Reuses one of two buffers, growing it only when a frame has more shapes than ever before.
    private func shapeBuffer(for primitives: [Primitive]) -> MTLBuffer? {
        bufferIndex = (bufferIndex + 1) % Self.framesInFlight
        let length = max(1, primitives.count) * MemoryLayout<Primitive>.stride
        if (shapeBuffers[bufferIndex]?.length ?? 0) < length {
            shapeBuffers[bufferIndex] = shared.device.makeBuffer(length: length * 5 / 4, options: .storageModeShared)
        }
        guard let buffer = shapeBuffers[bufferIndex] else { return nil }
        if !primitives.isEmpty {
            primitives.withUnsafeBytes { buffer.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        }
        return buffer
    }

    private func uploadNewLayers(of scene: LivingScene) {
        if let backdrop = scene.takeNewBackdrop() { backdropTexture = upload(backdrop) }
        if let image = scene.takeNewOverlay() { overlay = uploadIndexed(image) }
    }

    /// Overlays use only a handful of colours, so they're stored as one byte per pixel plus a palette:
    /// a quarter of the memory of a full-colour texture.
    private func uploadIndexed(_ image: PixelBuffer) -> (indices: MTLTexture, palette: [SIMD4<Float>])? {
        var palette: [SIMD4<Float>] = [.zero]
        var indexOf: [UInt32: UInt8] = [0: 0]
        var indices = [UInt8](repeating: 0, count: image.pixels.count)
        for (position, pixel) in image.pixels.enumerated() where pixel != 0 {
            if let index = indexOf[pixel] {
                indices[position] = index
                continue
            }
            // A palette fragment buffer holds 256 colours at most.
            guard palette.count < 256 else { return nil }
            indexOf[pixel] = UInt8(palette.count)
            indices[position] = UInt8(palette.count)
            palette.append(SIMD4(Float(pixel >> 16 & 0xff), Float(pixel >> 8 & 0xff), Float(pixel & 0xff), 255) / 255)
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: image.width, height: image.height, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = shared.device.makeTexture(descriptor: descriptor) else { return nil }
        indices.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0,
                            withBytes: bytes.baseAddress!, bytesPerRow: image.width)
        }
        return (texture, palette)
    }

    private func upload(_ image: PixelBuffer) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: image.width,
                                                                  height: image.height, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = shared.device.makeTexture(descriptor: descriptor) else { return nil }
        image.pixels.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0,
                            withBytes: bytes.baseAddress!, bytesPerRow: image.width * 4)
        }
        return texture
    }
}
