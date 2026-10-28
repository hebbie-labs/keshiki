import CoreGraphics
import Metal
import QuartzCore

/// Draws a scene's pixel art on the GPU, every recorded shape as an instanced quad, into two layers at the scene's
/// pixel size: what swims under the water, and what floats on it (with the overlay). It also moves the scene's
/// water on. `WaterStage` lays all of it out in 3D; `snapshot` flattens the layers over the backdrop instead.
/// One renderer per display; the device and pipelines are shared.
final class SceneRenderer {
    private struct Shared {
        let device: MTLDevice
        let queue: MTLCommandQueue
        let shapes: MTLRenderPipelineState
        let backdrop: MTLRenderPipelineState
        let overlay: MTLRenderPipelineState
        let flatten: MTLRenderPipelineState
        /// Covers for the flat snapshot, and for the stage's display texture (sRGB).
        let cover: MTLRenderPipelineState
        let stageCover: MTLRenderPipelineState
        let waterStep: MTLComputePipelineState
        let waterShape: MTLComputePipelineState

        init?() {
            guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
                  let library = try? device.makeLibrary(source: Shaders.source, options: nil) else { return nil }
            func pipeline(_ vertex: String, _ fragment: String, blending: Bool, format: MTLPixelFormat = SceneRenderer.pixelFormat) -> MTLRenderPipelineState? {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: vertex)
                descriptor.fragmentFunction = library.makeFunction(name: fragment)
                let attachment = descriptor.colorAttachments[0]!
                attachment.pixelFormat = format
                attachment.isBlendingEnabled = blending
                attachment.sourceRGBBlendFactor = .sourceAlpha
                attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                attachment.sourceAlphaBlendFactor = .one
                attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                return try? device.makeRenderPipelineState(descriptor: descriptor)
            }
            func kernel(_ name: String) -> MTLComputePipelineState? {
                library.makeFunction(name: name).flatMap { try? device.makeComputePipelineState(function: $0) }
            }
            guard let shapes = pipeline("shapeVertex", "shapeFragment", blending: true),
                  let backdrop = pipeline("fullScreenVertex", "backdropFragment", blending: false),
                  let overlay = pipeline("fullScreenVertex", "overlayFragment", blending: true),
                  let flatten = pipeline("fullScreenVertex", "flattenFragment", blending: false),
                  let cover = pipeline("fullScreenVertex", "coverFragment", blending: true),
                  let stageCover = pipeline("fullScreenVertex", "coverFragment", blending: true, format: WaterStage.pixelFormat),
                  let waterStep = kernel("waterStep"), let waterShape = kernel("waterShape") else { return nil }
            self.device = device
            self.queue = queue
            self.shapes = shapes
            self.backdrop = backdrop
            self.overlay = overlay
            self.flatten = flatten
            self.cover = cover
            self.stageCover = stageCover
            self.waterStep = waterStep
            self.waterShape = waterShape
        }
    }

    /// The simulated water: heights now and one step ago (two, swapped every step) and where it can't move.
    private struct Water {
        var heights: [MTLTexture]
        let obstacles: MTLTexture
        let columns: Int
        let rows: Int
        var time = 0.0
    }

    /// Design units per water cell.
    static let waterCell = 2.0
    private static let waterStepsPerFrame = 2
    private static let waveSpeed: Float = 0.25
    private static let waveDamping: Float = 0.985
    /// How deep a drop of strength 1 pushes the water, in design units.
    private static let dropDepth = 1.2

    static let pixelFormat = MTLPixelFormat.bgra8Unorm
    /// The format of the waves texture: slope x, slope y and curvature per design unit, and height.
    static let wavesFormat = MTLPixelFormat.rgba16Float
    private static let shared = Shared()

    private let shared: Shared
    private let drawList: DrawList
    private var backdropTexture: MTLTexture?
    private var water: Water?
    private var overlay: (indices: MTLTexture, palette: [SIMD4<Float>])?
    private var shapeBuffers: [MTLBuffer?] = [nil, nil]
    private var bufferIndex = 0
    /// Goes up whenever the scene painted a new backdrop, so `WaterStage` knows to copy it.
    private(set) var backdropVersion = 0

    static var isAvailable: Bool { shared != nil }
    static var device: MTLDevice? { shared?.device }
    static var queue: MTLCommandQueue? { shared?.queue }

    /// Uploads the scene's painted layers right away, so their CPU copies are freed
    /// even on a display that stays paused and never draws.
    init?(scene: LivingScene) {
        guard let shared = Self.shared else { return nil }
        self.shared = shared
        drawList = DrawList(width: scene.pixelWidth, height: scene.pixelHeight, scale: scene.pixelScale)
        if let surface = scene.water { water = makeWater(surface, width: scene.pixelWidth, height: scene.pixelHeight, scale: scene.pixelScale) }
        uploadNewLayers(of: scene)
    }

    /// The size of the waves texture `encodeWater` fills.
    var waterGrid: (columns: Int, rows: Int)? {
        water.map { ($0.columns, $0.rows) }
    }

    /// Records this frame's shapes; call before encoding the layers.
    func record(_ scene: LivingScene, at date: Date) {
        uploadNewLayers(of: scene)
        drawList.reset()
        scene.draw(on: drawList, at: date)
    }

    /// Draws what swims and what floats into two transparent layers (premultiplied) of the scene's pixel size.
    func encodeLayers(swimming: MTLTexture, floating: MTLTexture, commands: MTLCommandBuffer) {
        guard let shapes = shapeBuffer(for: drawList.primitives) else { return }
        let count = drawList.primitives.count
        let overlayStart = drawList.overlayIndex ?? count, surfaceStart = min(drawList.surfaceIndex ?? overlayStart, overlayStart)
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: Self.pass(into: swimming, clear: true)) else { return }
        drawShapes(shapes, range: 0..<surfaceStart, size: swimming, with: encoder)
        encoder.endEncoding()
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: Self.pass(into: floating, clear: true)) else { return }
        drawShapes(shapes, range: surfaceStart..<overlayStart, size: floating, with: encoder)
        if let overlay, drawList.overlayIndex != nil { drawOverlay(overlay.indices, palette: overlay.palette, with: encoder) }
        drawShapes(shapes, range: overlayStart..<count, size: floating, with: encoder)
        encoder.endEncoding()
    }

    /// The colours the scene laid over the whole frame this time, for `encodeCovers`.
    var covers: [Color] { drawList.covers }

    /// Lays colours over a finished stage frame.
    static func encodeCovers(_ covers: [Color], over target: MTLTexture, commands: MTLCommandBuffer) {
        guard let shared, !covers.isEmpty, let encoder = commands.makeRenderCommandEncoder(descriptor: pass(into: target, load: true)) else { return }
        drawCovers(covers, with: shared.stageCover, encoder: encoder)
        encoder.endEncoding()
    }

    private static func drawCovers(_ covers: [Color], with pipeline: MTLRenderPipelineState, encoder: MTLRenderCommandEncoder) {
        encoder.setRenderPipelineState(pipeline)
        for cover in covers {
            var color = SIMD4(Float(cover.red), Float(cover.green), Float(cover.blue), Float(cover.weight) * 255 / 256) / 255
            encoder.setFragmentBytes(&color, length: MemoryLayout.size(ofValue: color), index: 0)
            encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }
    }

    func encodeBackdropCopy(into target: MTLTexture, commands: MTLCommandBuffer) {
        guard let backdropTexture, let encoder = commands.makeRenderCommandEncoder(descriptor: Self.pass(into: target, clear: false)) else { return }
        encoder.setRenderPipelineState(shared.backdrop)
        encoder.setFragmentTexture(backdropTexture, index: 0)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    /// Moves the waves on by one frame, starting with the scene's new drops, and writes their slopes,
    /// curvature and height into `waves` (`waterGrid` in size).
    func encodeWater(_ surface: WaterSurface, into waves: MTLTexture, commands: MTLCommandBuffer) {
        guard var water, let encoder = commands.makeComputeCommandEncoder() else { return }
        let drops = surface.takeDrops()
        var cells = drops.map { drop in
            SIMD4<Float>(Float(drop.disc.center.x / Self.waterCell - 0.5), Float(drop.disc.center.y / Self.waterCell - 0.5),
                         Float(max(1, drop.disc.radius / Self.waterCell)), Float(drop.strength * Self.dropDepth))
        }
        if cells.isEmpty { cells.append(.zero) }
        let grid = MTLSize(width: water.columns, height: water.rows, depth: 1)
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
        encoder.setTexture(waves, index: 1)
        encoder.setBytes(&shape, length: MemoryLayout.size(ofValue: shape), index: 0)
        encoder.dispatchThreads(grid, threadsPerThreadgroup: group)
        encoder.endEncoding()
        self.water = water
    }

    /// The scene flat, without the water: the layers over the backdrop at the scene's own pixel size.
    func snapshot(_ scene: LivingScene, at date: Date = Date()) -> CGImage? {
        guard let target = makeTexture(scene.pixelWidth, scene.pixelHeight, storage: .shared),
              let swimming = makeTexture(scene.pixelWidth, scene.pixelHeight), let floating = makeTexture(scene.pixelWidth, scene.pixelHeight),
              let backdropTexture, let commands = shared.queue.makeCommandBuffer() else { return nil }
        record(scene, at: date)
        encodeLayers(swimming: swimming, floating: floating, commands: commands)
        guard let encoder = commands.makeRenderCommandEncoder(descriptor: Self.pass(into: target, clear: false)) else { return nil }
        encoder.setRenderPipelineState(shared.flatten)
        encoder.setFragmentTexture(backdropTexture, index: 0)
        encoder.setFragmentTexture(swimming, index: 1)
        encoder.setFragmentTexture(floating, index: 2)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        Self.drawCovers(drawList.covers, with: shared.cover, encoder: encoder)
        encoder.endEncoding()
        commands.commit()
        commands.waitUntilCompleted()
        let image = PixelBuffer(width: target.width, height: target.height)
        image.pixels.withUnsafeMutableBytes { bytes in
            target.getBytes(bytes.baseAddress!, bytesPerRow: target.width * 4, from: MTLRegionMake2D(0, 0, target.width, target.height), mipmapLevel: 0)
        }
        return image.makeImage()
    }

    private static func pass(into texture: MTLTexture, clear: Bool = false, load: Bool = false) -> MTLRenderPassDescriptor {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = clear ? .clear : load ? .load : .dontCare
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        return pass
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
        bufferIndex = (bufferIndex + 1) % shapeBuffers.count
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

    private func makeTexture(_ width: Int, _ height: Int, storage: MTLStorageMode = .private) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = storage
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
              let obstacles = texture(.r8Unorm, .shaderRead) else { return nil }
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
        return Water(heights: [first, second], obstacles: obstacles, columns: columns, rows: rows)
    }

    private func uploadNewLayers(of scene: LivingScene) {
        if let backdrop = scene.takeNewBackdrop() {
            backdropTexture = upload(backdrop)
            backdropVersion += 1
        }
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
