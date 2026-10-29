import CoreGraphics
import Metal
import QuartzCore
import simd

/// A scene with water, in 3D, seen from a slightly tilted camera: the painted floor as a basin at its depth,
/// what swims as a pixel-art layer under the surface, and the surface itself, moved by the simulated waves,
/// carrying what floats and reflecting the sky and the sun. The water between them bends, shades and colours
/// what lies below (`StageShaders`). Each frame is one GPU submission. One stage per display.
final class WaterStage {
    private struct Camera {
        let position: SIMD3<Float>
        let forward: SIMD3<Float>
        let right: SIMD3<Float>
        let up: SIMD3<Float>
        let tanHalf: Float
        let aspect: Float

        /// Looks down at the middle of the pond, tilted so the far edge sits at the top of the screen.
        init(aspect: Float) {
            position = SIMD3(0, WaterStage.cameraHeight, WaterStage.cameraHeight * tan(WaterStage.tilt))
            forward = normalize(-position)
            right = normalize(cross(forward, SIMD3(0, 1, 0)))
            up = cross(right, forward)
            tanHalf = tan(WaterStage.fieldOfView / 2 * .pi / 180)
            self.aspect = aspect
        }

        /// Where the ray through a spot on the screen (0...1, origin top-left) meets the water.
        func water(at spot: Point) -> SIMD3<Float> {
            let x = Float(spot.x * 2 - 1) * tanHalf * aspect, y = Float(1 - spot.y * 2) * tanHalf
            let ray = forward + right * x + up * y
            return position + ray * (-position.y / ray.y)
        }

        func spot(of point: SIMD3<Float>) -> Point {
            let offset = point - position, ahead = dot(offset, forward)
            let x = dot(offset, right) / ahead / (tanHalf * aspect), y = dot(offset, up) / ahead / tanHalf
            return Point(x: Double(x + 1) / 2, y: Double(1 - y) / 2)
        }

        var viewProjection: simd_float4x4 {
            let back = -forward
            let view = simd_float4x4(columns: (SIMD4(right.x, up.x, back.x, 0), SIMD4(right.y, up.y, back.y, 0),
                                               SIMD4(right.z, up.z, back.z, 0),
                                               SIMD4(-dot(right, position), -dot(up, position), -dot(back, position), 1)))
            let near: Float = 0.1, far: Float = 100, focal = 1 / tanHalf
            let projection = simd_float4x4(columns: (SIMD4(focal / aspect, 0, 0, 0), SIMD4(0, focal, 0, 0),
                                                     SIMD4(0, 0, far / (near - far), -1), SIMD4(0, 0, near * far / (near - far), 0)))
            return projection * view
        }
    }

    /// The pond's rectangle on the water: as wide as the screen at its far edge, reaching down to the near edge.
    /// The near corners lie just off screen, the way the edge of a real pond would.
    private struct Pond {
        let width: Float
        let far: Float
        let length: Float

        init(seenBy camera: Camera) {
            let farRight = camera.water(at: Point(x: 1, y: 0))
            width = farRight.x * 2
            far = farRight.z
            length = camera.water(at: Point(x: 0.5, y: 1)).z - far
        }

        func point(at spot: Point, height: Float = 0) -> SIMD3<Float> {
            SIMD3((Float(spot.x) - 0.5) * width, height, far + Float(spot.y) * length)
        }
    }

    /// Must match `StageVertex` in the shader.
    private struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
        var spot: SIMD2<Float>
    }

    private struct Mesh {
        let vertices: MTLBuffer
        let indices: MTLBuffer
        let count: Int
    }

    /// Must match `Stage` in the shader.
    private struct Uniforms {
        var viewProjection: simd_float4x4
        var eye: SIMD4<Float>
        var pond: SIMD4<Float>
        var water: SIMD4<Float>
        var sun: SIMD4<Float>
        var slant: SIMD4<Float>
        var light: SIMD4<Float>
    }

    private struct Shared {
        let floor: MTLRenderPipelineState
        let swimmers: MTLRenderPipelineState
        let surface: MTLRenderPipelineState
        let standing: MTLRenderPipelineState
        let writeDepth: MTLDepthStencilState
        let readDepth: MTLDepthStencilState

        init?() {
            guard let device = SceneRenderer.device, let library = try? device.makeLibrary(source: StageShaders.source, options: nil) else { return nil }
            func pipeline(_ fragment: String, vertex: String = "stageVertex", premultiplied: Bool? = nil) -> MTLRenderPipelineState? {
                let descriptor = MTLRenderPipelineDescriptor()
                descriptor.vertexFunction = library.makeFunction(name: vertex)
                descriptor.fragmentFunction = library.makeFunction(name: fragment)
                descriptor.depthAttachmentPixelFormat = .depth32Float
                let attachment = descriptor.colorAttachments[0]!
                attachment.pixelFormat = WaterStage.pixelFormat
                if let premultiplied {
                    attachment.isBlendingEnabled = true
                    attachment.sourceRGBBlendFactor = premultiplied ? .one : .sourceAlpha
                    attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
                    attachment.sourceAlphaBlendFactor = .one
                    attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
                }
                return try? device.makeRenderPipelineState(descriptor: descriptor)
            }
            func depth(write: Bool) -> MTLDepthStencilState? {
                let descriptor = MTLDepthStencilDescriptor()
                descriptor.depthCompareFunction = .less
                descriptor.isDepthWriteEnabled = write
                return device.makeDepthStencilState(descriptor: descriptor)
            }
            guard let floor = pipeline("floorFragment"), let swimmers = pipeline("swimmersFragment", premultiplied: false),
                  let surface = pipeline("surfaceFragment", premultiplied: true),
                  let standing = pipeline("standingFragment", vertex: "standingVertex"),
                  let writeDepth = depth(write: true), let readDepth = depth(write: false) else { return nil }
            self.floor = floor
            self.swimmers = swimmers
            self.surface = surface
            self.standing = standing
            self.writeDepth = writeDepth
            self.readDepth = readDepth
        }
    }

    private static let tilt: Float = 25 * .pi / 180
    private static let fieldOfView: Float = 32
    private static let cameraHeight: Float = 10
    /// Seen through water, everything below looks this much shallower than it is (1 / 1.33), so the floor and
    /// the swimmers are placed at that depth; the shaders work with the real one.
    private static let apparentDepth: Float = 0.75
    /// How deep the swimmers swim, in design units.
    private static let swimmerDepth: Float = 5
    /// How far the floor and the water reach past the pond on every side, as a share of its size.
    private static let margin: Float = 0.12
    /// The sun stands a little behind and to the left of the viewer, 26° from straight up: then the light a wave
    /// casts onto the floor lands where the wave is seen, while shadows still fall away the deeper the floor.
    private static let sunDirection = normalize(SIMD3<Float>(-0.12, 0.9, 0.42))
    /// The same sunlight bent into the water: how far it moves sideways per unit of depth (sin 26° / 1.33 → tan).
    private static let sunSlant = SIMD2<Float>(-0.096, 0.336)
    /// How steep the waves look to the light.
    private static let waveRelief: Float = 6

    static let pixelFormat = MTLPixelFormat.bgra8Unorm_srgb
    private static let shared = Shared()

    let scene: LivingScene
    private let shared: Shared
    private let layers: SceneRenderer
    private let surface: WaterSurface
    private let camera: Camera
    private let pond: Pond
    private let swimming: MTLTexture
    private let floating: MTLTexture
    private let waves: MTLTexture
    private let sky: MTLTexture
    private let floorMesh: Mesh
    private let swimmersMesh: Mesh
    private let surfaceMesh: Mesh
    /// Reeds and the like, standing up at the edges; nil if the scene has none.
    private let standing: (sheet: MTLTexture, mesh: Mesh)?
    private var uniforms: Uniforms
    private var depth: MTLTexture?
    /// Seconds of wind, for the swaying.
    private var clock: Float = 0

    /// The pond's width to length, so the scene can be made in that shape.
    static func pondAspect(screenAspect: Double) -> Double {
        let pond = Pond(seenBy: Camera(aspect: Float(screenAspect)))
        return Double(pond.width / pond.length)
    }

    static func configure(_ layer: CAMetalLayer, width: Int, height: Int) {
        layer.device = SceneRenderer.device
        layer.pixelFormat = pixelFormat
        layer.framebufferOnly = true
        layer.maximumDrawableCount = 2
        layer.drawableSize = CGSize(width: width, height: height)
        layer.magnificationFilter = .linear
        layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        layer.isOpaque = true
    }

    init?(scene: LivingScene, screenAspect: Double) {
        guard let shared = Self.shared, let device = SceneRenderer.device, let surface = scene.water,
              let layers = SceneRenderer(scene: scene), let grid = layers.waterGrid else { return nil }
        func texture(_ format: MTLPixelFormat, _ width: Int, _ height: Int, _ usage: MTLTextureUsage) -> MTLTexture? {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
            descriptor.usage = usage
            descriptor.storageMode = .private
            return device.makeTexture(descriptor: descriptor)
        }
        let camera = Camera(aspect: Float(screenAspect)), pond = Pond(seenBy: camera)
        let size = SIMD2(Float(scene.pixelWidth), Float(scene.pixelHeight)) / Float(scene.pixelScale)
        let unit = pond.width / size.x
        let depthAt = { (spot: Point) in Float(surface.depth(Point(x: spot.x * Double(size.x), y: spot.y * Double(size.y)))) }
        guard let swimming = texture(SceneRenderer.pixelFormat, scene.pixelWidth, scene.pixelHeight, [.renderTarget, .shaderRead]),
              let floating = texture(SceneRenderer.pixelFormat, scene.pixelWidth, scene.pixelHeight, [.renderTarget, .shaderRead]),
              let waves = texture(SceneRenderer.wavesFormat, grid.columns, grid.rows, [.shaderWrite, .shaderRead]),
              let sky = Self.upload(Self.paintSky(), to: device),
              let floorMesh = Self.grid(pond, columns: 160, rows: 110, device: device, height: { -depthAt($0) * unit * Self.apparentDepth }),
              let swimmersMesh = Self.grid(pond, columns: 1, rows: 1, device: device, height: { _ in -Self.swimmerDepth * unit * Self.apparentDepth }),
              let surfaceMesh = Self.grid(pond, columns: 200, rows: 140, device: device, height: { _ in 0 }) else { return nil }
        self.scene = scene
        self.shared = shared
        self.layers = layers
        self.surface = surface
        self.camera = camera
        self.pond = pond
        self.swimming = swimming
        self.floating = floating
        self.waves = waves
        self.sky = sky
        self.floorMesh = floorMesh
        self.swimmersMesh = swimmersMesh
        self.surfaceMesh = surfaceMesh
        standing = scene.takeNewStanding().flatMap { Self.stand($0, in: pond, size: size, scale: Float(scene.pixelScale), device: device) }
        uniforms = Uniforms(viewProjection: camera.viewProjection, eye: SIMD4(camera.position, Self.apparentDepth),
                            pond: SIMD4(size.x, size.y, unit, Self.swimmerDepth), water: .zero,
                            sun: SIMD4(Self.sunDirection, 0), slant: SIMD4(Self.sunSlant.x, Self.sunSlant.y, 0, 0), light: .zero)
    }

    /// Records the scene, moves the water on (unless it's a still), draws the stage into `target` and lays the
    /// scene's covers (the light of the time of day) over it. `completion` gets the command buffer before it's
    /// committed, e.g. to present a drawable.
    func render(into target: MTLTexture, at date: Date = Date(), simulate: Bool = true, completion: ((MTLCommandBuffer) -> Void)? = nil) {
        guard let commands = SceneRenderer.queue?.makeCommandBuffer(), let depth = depthTexture(for: target) else { return }
        layers.record(scene, at: date)
        layers.encodeLayers(swimming: swimming, floating: floating, commands: commands)
        if simulate {
            layers.encodeWater(surface, into: waves, commands: commands)
            clock = (clock + 1.0 / 30).truncatingRemainder(dividingBy: 600)
        }
        uniforms.slant.z = clock
        uniforms.slant.w = Float(surface.murk)
        func linear(_ color: Color) -> SIMD3<Float> {
            SIMD3(pow(Float(color.red) / 255, 2.2), pow(Float(color.green) / 255, 2.2), pow(Float(color.blue) / 255, 2.2))
        }
        uniforms.water = SIMD4(linear(surface.color), Self.waveRelief)
        uniforms.light = SIMD4(linear(surface.glow) * Float(surface.glow.weight) / 256, Float(surface.sunlight))

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        if let encoder = commands.makeRenderCommandEncoder(descriptor: pass) {
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setVertexTexture(waves, index: 0)
            for (index, texture) in [layers.backdrop, swimming, floating, waves, sky].enumerated() {
                encoder.setFragmentTexture(texture, index: index)
            }
            encoder.setDepthStencilState(shared.writeDepth)
            draw(floorMesh, with: shared.floor, lift: 0, encoder: encoder)
            encoder.setDepthStencilState(shared.readDepth)
            draw(swimmersMesh, with: shared.swimmers, lift: 0, encoder: encoder)
            draw(surfaceMesh, with: shared.surface, lift: 1, encoder: encoder)
            if let standing {
                encoder.setDepthStencilState(shared.writeDepth)
                encoder.setFragmentTexture(standing.sheet, index: 5)
                draw(standing.mesh, with: shared.standing, lift: 0, encoder: encoder)
            }
            encoder.endEncoding()
        }
        SceneRenderer.encodeCovers(layers.covers, over: target, commands: commands)
        completion?(commands)
        commands.commit()
    }

    /// A still of the current frame, e.g. for the lock screen; the water doesn't move on for it.
    func snapshot(width: Int, height: Int) -> CGImage? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = SceneRenderer.device?.makeTexture(descriptor: descriptor) else { return nil }
        var finished: MTLCommandBuffer?
        render(into: texture, simulate: false) { finished = $0 }
        finished?.waitUntilCompleted()
        let image = PixelBuffer(width: width, height: height)
        image.pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return image.makeImage()
    }

    /// The pond spot (0...1 across the pond) under a spot on the screen (0...1, origin top-left).
    func pondSpot(forViewSpot spot: Point) -> Point {
        let point = camera.water(at: spot)
        return Point(x: Double(point.x / pond.width + 0.5), y: Double((point.z - pond.far) / pond.length))
    }

    /// Where a pond spot shows on the screen.
    func viewSpot(forPondSpot spot: Point) -> Point {
        camera.spot(of: pond.point(at: spot))
    }

    private func draw(_ mesh: Mesh, with pipeline: MTLRenderPipelineState, lift: Float, encoder: MTLRenderCommandEncoder) {
        var lift = lift
        encoder.setRenderPipelineState(pipeline)
        encoder.setVertexBuffer(mesh.vertices, offset: 0, index: 0)
        encoder.setVertexBytes(&lift, length: MemoryLayout<Float>.size, index: 2)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.count, indexType: .uint32, indexBuffer: mesh.indices, indexBufferOffset: 0)
    }

    /// Depth only matters while a frame is drawn, so it lives in tile memory and takes no RAM.
    private func depthTexture(for target: MTLTexture) -> MTLTexture? {
        if let depth, depth.width == target.width, depth.height == target.height { return depth }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: target.width, height: target.height, mipmapped: false)
        descriptor.usage = .renderTarget
        descriptor.storageMode = .memoryless
        depth = SceneRenderer.device?.makeTexture(descriptor: descriptor)
        return depth
    }

    /// A grid over the pond and the margin around it, with the pond's 0...1 as `spot`,
    /// each vertex lifted to `height(spot)` and its normal following the slope.
    private static func grid(_ pond: Pond, columns: Int, rows: Int, device: MTLDevice, height: (Point) -> Float) -> Mesh? {
        let step = SIMD2(Double(1 + 2 * margin) / Double(columns), Double(1 + 2 * margin) / Double(rows))
        func spot(_ column: Int, _ row: Int) -> Point {
            Point(x: Double(-margin) + Double(column) * step.x, y: Double(-margin) + Double(row) * step.y)
        }
        func position(_ column: Int, _ row: Int) -> SIMD3<Float> {
            let spot = spot(column, row)
            return pond.point(at: spot, height: height(spot))
        }
        var vertices: [Vertex] = [], indices: [UInt32] = []
        for row in 0...rows {
            for column in 0...columns {
                let across = position(min(column + 1, columns), row) - position(max(column - 1, 0), row)
                let along = position(column, min(row + 1, rows)) - position(column, max(row - 1, 0))
                let spot = spot(column, row)
                vertices.append(Vertex(position: position(column, row), normal: normalize(cross(along, across)),
                                       spot: SIMD2(Float(spot.x), Float(spot.y))))
            }
        }
        let stride = UInt32(columns + 1)
        for row in 0..<UInt32(rows) {
            for column in 0..<UInt32(columns) {
                let corner = row * stride + column
                indices += [corner, corner + stride, corner + 1, corner + 1, corner + stride, corner + stride + 1]
            }
        }
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride),
              let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride) else { return nil }
        return Mesh(vertices: vertexBuffer, indices: indexBuffer, count: indices.count)
    }

    /// One upright quad per sprite: every corner sits at the root and carries its offset in `normal`.
    private static func stand(_ standing: Standing, in pond: Pond, size: SIMD2<Float>, scale: Float, device: MTLDevice) -> (MTLTexture, Mesh)? {
        guard let sheet = upload(standing.sheet, to: device) else { return nil }
        let unit = pond.width / size.x, sheetSize = SIMD2(Float(standing.sheet.width), Float(standing.sheet.height))
        var vertices: [Vertex] = [], indices: [UInt32] = []
        for sprite in standing.sprites {
            let root = pond.point(at: Point(x: sprite.root.x / Double(size.x), y: sprite.root.y / Double(size.y)))
            let width = Float(sprite.width) / scale * unit, height = Float(sprite.height) / scale * unit
            let first = UInt32(vertices.count)
            for (across, up) in [(Float(0), Float(0)), (1, 0), (0, 1), (1, 1)] {
                let cell = SIMD2(Float(sprite.x) + across * Float(sprite.width), Float(sprite.y) + (1 - up) * Float(sprite.height))
                vertices.append(Vertex(position: root, normal: SIMD3((across - 0.5) * width, up * height, Float(sprite.phase)), spot: cell / sheetSize))
            }
            indices += [first, first + 1, first + 2, first + 2, first + 1, first + 3]
        }
        guard !indices.isEmpty,
              let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<Vertex>.stride),
              let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride) else { return nil }
        return (sheet, Mesh(vertices: vertexBuffer, indices: indexBuffer, count: indices.count))
    }

    private static func upload(_ image: PixelBuffer, to device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat, width: image.width, height: image.height, mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        image.pixels.withUnsafeBytes {
            texture.replace(region: MTLRegionMake2D(0, 0, image.width, image.height), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: image.width * 4)
        }
        return texture
    }

    /// The sky the water reflects, as a panorama: blue overhead, paler towards the horizon, with soft clouds,
    /// and a ring of trees around the pond below the horizon.
    private static func paintSky() -> PixelBuffer {
        let width = 256, height = 128
        let sky = PixelBuffer(width: width, height: height)
        let zenith = Color(0x4f8fd0), horizon = Color(0xd8ecf0), trees = Color(0x3a4436), ground = Color(0x4a4438)
        for y in 0..<height {
            let elevation = 90 - Double(y) / Double(height) * 180
            for x in 0..<width {
                let turn = Double(x) / Double(width) * 2 * .pi
                let treeline = 8 + 4 * sin(turn * 7) + 3 * sin(turn * 19 + 1)
                var color = elevation < 0 ? ground : elevation < treeline ? trees : horizon.mixed(with: zenith, pow(elevation / 90, 0.6))
                let cloud = (sin(turn * 5 + elevation * 0.08) + sin(turn * 11 - elevation * 0.05) + sin(turn * 3 + 2)) / 3
                if elevation > treeline + 4, cloud > 0.35 { color = color.mixed(with: Color(0xffffff), min(1, (cloud - 0.35) * 3)) }
                sky.plot(x, y, color)
            }
        }
        return sky
    }
}
