import CoreGraphics
import Metal
import QuartzCore

/// Draws a scene on the GPU: its backdrop and every recorded shape as instanced quads, in two layers at the scene's
/// pixel size (below and above the overlay), then puts them together at the display's resolution with the water
/// in between: simulated waves that bend, light and reflect the layer below. One renderer per display; the device
/// and pipelines are shared.
final class SceneRenderer {
    private struct Shared {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let shapes: MTLRenderPipelineState
        let backdrop: MTLRenderPipelineState
        let overlay: MTLRenderPipelineState
        let compose: MTLRenderPipelineState
        let waterStep: MTLComputePipelineState
        let waterShape: MTLComputePipelineState

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
                  let compose = pipeline("fullScreenVertex", "waterFragment", blending: false),
                  let waterStep = library.makeFunction(name: "waterStep").flatMap({ try? device.makeComputePipelineState(function: $0) }),
                  let waterShape = library.makeFunction(name: "waterShape").flatMap({ try? device.makeComputePipelineState(function: $0) })
            else { return nil }
            self.device = device
            self.queue = queue
            self.shapes = shapes
            self.backdrop = backdrop
            self.overlay = overlay
            self.compose = compose
            self.waterStep = waterStep
            self.waterShape = waterShape
        }
    }

    /// The simulated water of one scene: heights now and one step ago (two, swapped every step),
    /// the slopes and curvature for shading, and where the water can't move.
    private struct Water {
        var heights: [MTLTexture]
        let shape: MTLTexture
        let obstacles: MTLTexture
        var time = 0.0
    }

    /// Design units per water cell.
    private static let waterCell = 2.0
    private static let waterStepsPerFrame = 2
    private static let waveSpeed: Float = 0.25
    private static let waveDamping: Float = 0.985
    /// How deep a drop of strength 1 pushes the water, in design units.
    private static let dropDepth = 1.2
    /// How far the waves shift the floor, how deep the floor lies for the light net, and how steep waves look for glints.
    private static let refraction: Float = 9
    private static let floorDepth: Float = 90
    private static let waveRelief: Float = 2.5
    private static let lightNetStrength: Float = 0.3

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
    /// The scene's layers below and above its overlay, at its own pixel size; the above layer is premultiplied.
    private var below: MTLTexture?
    private var above: MTLTexture?
    private var water: Water?
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
        below = makeLayer(width: scene.pixelWidth, height: scene.pixelHeight)
        above = makeLayer(width: scene.pixelWidth, height: scene.pixelHeight)
        if let surface = scene.water { water = makeWater(surface, width: scene.pixelWidth, height: scene.pixelHeight, scale: scene.pixelScale) }
        uploadNewLayers(of: scene)
    }

    /// Draws the next frame of every job into its layer, all in one GPU submission: each submission
    /// costs a trip into the kernel, so three displays share one instead of paying three times.
    static func render(_ jobs: [Job], at date: Date = Date(), completion: ((MTLCommandBuffer) -> Void)? = nil) {
        guard !jobs.isEmpty, let shared, let commands = shared.queue.makeCommandBuffer() else { return }
        inFlight.wait()
        for job in jobs {
            guard let drawable = job.layer.nextDrawable() else { continue }
            job.renderer.encode(job.scene, into: drawable.texture, at: date, commands: commands, simulate: true)
            commands.present(drawable)
        }
        commands.addCompletedHandler { buffer in
            completion?(buffer)
            inFlight.signal()
        }
        commands.commit()
    }

    /// A still of the scene's current frame, e.g. for the lock screen. The water doesn't move on for it.
    /// It has the scene's own pixel size unless given another, e.g. the display's.
    func snapshot(_ scene: LivingScene, at date: Date = Date(), width: Int? = nil, height: Int? = nil) -> CGImage? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: width ?? scene.pixelWidth,
                                                                  height: height ?? scene.pixelHeight, mipmapped: false)
        descriptor.usage = .renderTarget
        descriptor.storageMode = .shared
        Self.inFlight.wait()
        defer { Self.inFlight.signal() }
        guard let texture = shared.device.makeTexture(descriptor: descriptor), let commands = shared.queue.makeCommandBuffer() else { return nil }
        encode(scene, into: texture, at: date, commands: commands, simulate: false)
        commands.commit()
        commands.waitUntilCompleted()
        let image = PixelBuffer(width: texture.width, height: texture.height)
        image.pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        return image.makeImage()
    }

    private func encode(_ scene: LivingScene, into target: MTLTexture, at date: Date, commands: MTLCommandBuffer, simulate: Bool) {
        uploadNewLayers(of: scene)
        drawList.reset()
        scene.draw(on: drawList, at: date)
        guard let backdropTexture, let below, let above, let shapes = shapeBuffer(for: drawList.primitives) else { return }
        if simulate, let surface = scene.water { simulateWater(dropping: surface.takeDrops(), commands: commands) }
        let count = drawList.primitives.count, split = drawList.overlayIndex ?? count
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: Self.pass(into: below, clear: false)) else { return }
        drawBackdrop(backdropTexture, with: encoder)
        drawShapes(shapes, range: 0..<split, size: below, with: encoder)
        encoder.endEncoding()
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: Self.pass(into: above, clear: true)) else { return }
        if let overlay, drawList.overlayIndex != nil { drawOverlay(overlay.indices, palette: overlay.palette, with: encoder) }
        drawShapes(shapes, range: split..<count, size: above, with: encoder)
        encoder.endEncoding()
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: Self.pass(into: target, clear: false)) else { return }
        compose(below: below, above: above, into: target, scale: scene.pixelScale, with: encoder)
        encoder.endEncoding()
    }

    private static func pass(into texture: MTLTexture, clear: Bool) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = clear ? .clear : .dontCare
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        return pass
    }

    private func drawBackdrop(_ texture: MTLTexture, with encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(shared.backdrop)
        encoder.setFragmentTexture(texture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func compose(below: MTLTexture, above: MTLTexture, into target: MTLTexture, scale: Double, with encoder: MTLRenderCommandEncoder) {
        let light = WaterSurface.light
        var look = (
            SIMD4<Float>(Float(target.width), Float(target.height), Float(Double(below.width) / scale), Float(Double(below.height) / scale)),
            SIMD4<Float>(Self.refraction, Self.floorDepth, Self.waveRelief, water == nil ? 0 : 1),
            SIMD4<Float>(Float(light.red) / 255, Float(light.green) / 255, Float(light.blue) / 255, Self.lightNetStrength)
        )
        encoder.setRenderPipelineState(shared.compose)
        encoder.setFragmentTexture(below, index: 0)
        encoder.setFragmentTexture(above, index: 1)
        encoder.setFragmentTexture(water?.shape, index: 2)
        encoder.setFragmentBytes(&look, length: MemoryLayout.size(ofValue: look), index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    /// Moves the waves on by one frame, starting with this frame's drops, then works out their slopes for shading.
    private func simulateWater(dropping drops: [WaterSurface.Drop], commands: MTLCommandBuffer) {
        guard var water, let encoder = commands.makeComputeCommandEncoder() else { return }
        var cells = drops.map { drop in
            SIMD4<Float>(Float(drop.disc.center.x / Self.waterCell - 0.5), Float(drop.disc.center.y / Self.waterCell - 0.5),
                         Float(max(1, drop.disc.radius / Self.waterCell)), Float(drop.strength * Self.dropDepth))
        }
        if cells.isEmpty { cells.append(.zero) }
        let grid = MTLSize(width: water.shape.width, height: water.shape.height, depth: 1)
        let group = MTLSize(width: 16, height: 16, depth: 1)
        encoder.setComputePipelineState(shared.waterStep)
        encoder.setTexture(water.obstacles, index: 2)
        for step in 0..<Self.waterStepsPerFrame {
            var uniforms = SIMD4<Float>(Self.waveSpeed, Self.waveDamping, step == 0 ? Float(drops.count) : 0, 0)
            encoder.setTexture(water.heights[0], index: 0)
            encoder.setTexture(water.heights[1], index: 1)
            cells.withUnsafeBytes { encoder.setBytes($0.baseAddress!, length: $0.count, index: 0) }
            encoder.setBytes(&uniforms, length: MemoryLayout.size(ofValue: uniforms), index: 1)
            encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
            water.heights.swapAt(0, 1)
        }
        // ponytail: assumes 30 frames a second, which is how often the app and the screensaver draw.
        water.time = (water.time + 1.0 / 30).truncatingRemainder(dividingBy: 600)
        var shape = SIMD4<Float>(Float(water.time), Float(Self.waterCell), 0, 0)
        encoder.setComputePipelineState(shared.waterShape)
        encoder.setTexture(water.heights[0], index: 0)
        encoder.setTexture(water.shape, index: 1)
        encoder.setBytes(&shape, length: MemoryLayout.size(ofValue: shape), index: 0)
        encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
        encoder.endEncoding()
        self.water = water
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

    private func makeLayer(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        return shared.device.makeTexture(descriptor: descriptor)
    }

    /// Flat water to start with; the obstacles are painted once into a mask of cells.
    private func makeWater(_ surface: WaterSurface, width: Int, height: Int, scale: Double) -> Water? {
        let columns = Int((Double(width) / scale / Self.waterCell).rounded(.up)), rows = Int((Double(height) / scale / Self.waterCell).rounded(.up))
        func texture(_ format: MTLPixelFormat, _ usage: MTLTextureUsage) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: columns, height: rows, mipmapped: false)
            descriptor.usage = usage
            descriptor.storageMode = .shared
            return shared.device.makeTexture(descriptor: descriptor)
        }
        guard let first = texture(.rg32Float, [.shaderRead, .shaderWrite]), let second = texture(.rg32Float, [.shaderRead, .shaderWrite]),
              let shape = texture(.rgba16Float, [.shaderRead, .shaderWrite]), let obstacles = texture(.r8Unorm, .shaderRead) else { return nil }
        let flat = [Float](repeating: 0, count: columns * rows * 2)
        for heights in [first, second] {
            flat.withUnsafeBytes { heights.replace(region: MTLRegionMake2D(0, 0, columns, rows), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: columns * 8) }
        }
        var mask = [UInt8](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let center = Point(x: (Double(column) + 0.5) * Self.waterCell, y: (Double(row) + 0.5) * Self.waterCell)
                // A cell counts as blocked when it lies wholly under the obstacle, so the water reaches its rim.
                if surface.obstacles.contains(where: { center.distance(to: $0.center) < $0.radius - Self.waterCell }) { mask[row * columns + column] = 255 }
            }
        }
        mask.withUnsafeBytes { obstacles.replace(region: MTLRegionMake2D(0, 0, columns, rows), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: columns) }
        return Water(heights: [first, second], shape: shape, obstacles: obstacles)
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
