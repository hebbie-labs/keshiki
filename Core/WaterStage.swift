import AppKit
import Metal
import QuartzCore
import RealityKit

/// A scene with water, in 3D, seen from a slightly tilted camera: the painted floor as a basin at its real depth,
/// what swims as a pixel-art layer under the surface, and the surface itself, moved by the simulated waves,
/// carrying what floats and reflecting the sky and the sun. The water between them bends, shades and colours
/// what lies below (`StageShaders`). RealityKit draws it into a texture on demand, so the app's own clock
/// still decides when frames happen. One stage per display.
@MainActor
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

    nonisolated private static let tilt: Float = 25 * .pi / 180
    nonisolated private static let fieldOfView: Float = 32
    nonisolated private static let cameraHeight: Float = 10
    /// How deep the swimmers swim, in design units.
    private static let swimmerDepth: Float = 5
    /// How far the floor and the water reach past the pond on every side, as a share of its size.
    private static let margin: Float = 0.12
    private static let sunDirection = normalize(SIMD3<Float>(-0.38, 1.8, -0.5))

    nonisolated static let pixelFormat = MTLPixelFormat.bgra8Unorm_srgb

    let scene: LivingScene
    private let layers: SceneRenderer
    private let surface: WaterSurface
    private let renderer: RealityRenderer
    private let camera: Camera
    private let pond: Pond
    private let floorTexture: LowLevelTexture
    private let swimming: LowLevelTexture
    private let floating: LowLevelTexture
    private let waves: LowLevelTexture
    private let models: [ModelEntity]
    private var floorVersion = 0
    private var waterColor: Color?

    /// The pond's width to length, so the scene can be made in that shape.
    nonisolated static func pondAspect(screenAspect: Double) -> Double {
        let pond = Pond(seenBy: Camera(aspect: Float(screenAspect)))
        return Double(pond.width / pond.length)
    }

    static func configure(_ layer: CAMetalLayer, width: Int, height: Int) {
        layer.device = SceneRenderer.device
        layer.pixelFormat = pixelFormat
        layer.framebufferOnly = false
        layer.maximumDrawableCount = 2
        layer.drawableSize = CGSize(width: width, height: height)
        layer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        layer.isOpaque = true
    }

    init?(scene: LivingScene, screenAspect: Double) {
        guard let surface = scene.water, let layers = SceneRenderer(scene: scene), let grid = layers.waterGrid,
              let renderer = try? RealityRenderer() else { return nil }
        func texture(_ format: MTLPixelFormat, _ width: Int, _ height: Int, _ usage: MTLTextureUsage) -> LowLevelTexture? {
            try? LowLevelTexture(descriptor: .init(pixelFormat: format, width: width, height: height, textureUsage: usage))
        }
        let layerUsage: MTLTextureUsage = [.renderTarget, .shaderRead]
        guard let floorTexture = texture(SceneRenderer.pixelFormat, scene.pixelWidth, scene.pixelHeight, layerUsage),
              let swimming = texture(SceneRenderer.pixelFormat, scene.pixelWidth, scene.pixelHeight, layerUsage),
              let floating = texture(SceneRenderer.pixelFormat, scene.pixelWidth, scene.pixelHeight, layerUsage),
              let waves = texture(SceneRenderer.wavesFormat, grid.columns, grid.rows, [.shaderWrite, .shaderRead]),
              let device = SceneRenderer.device, let library = try? device.makeLibrary(source: StageShaders.source, options: nil)
        else { return nil }
        self.scene = scene
        self.layers = layers
        self.surface = surface
        self.renderer = renderer
        self.floorTexture = floorTexture
        self.swimming = swimming
        self.floating = floating
        self.waves = waves
        camera = Camera(aspect: Float(screenAspect))
        pond = Pond(seenBy: camera)

        let size = SIMD2(Float(scene.pixelWidth), Float(scene.pixelHeight)) / Float(scene.pixelScale)
        let unit = pond.width / size.x
        do {
            func material(_ shader: String, waves geometry: String? = nil, lit: Bool = true, transparent: Bool = false) throws -> CustomMaterial {
                var material = try CustomMaterial(surfaceShader: .init(named: shader, in: library),
                                                  geometryModifier: geometry.map { .init(named: $0, in: library) },
                                                  lightingModel: lit ? .lit : .unlit)
                material.baseColor.texture = .init(try TextureResource(from: floorTexture))
                material.ambientOcclusion.texture = .init(try TextureResource(from: swimming))
                material.emissiveColor.texture = .init(try TextureResource(from: floating))
                material.custom = .init(value: SIMD4(size.x, size.y, unit, Self.swimmerDepth), texture: .init(try TextureResource(from: waves)))
                material.faceCulling = .none
                if transparent { material.blending = .transparent(opacity: .init(scale: 1)) }
                return material
            }
            let floor = ModelEntity(mesh: try Self.grid(pond, columns: 160, rows: 110) { spot in
                -Float(surface.depth(Point(x: spot.x * Double(size.x), y: spot.y * Double(size.y)))) * unit
            }, materials: [try material("pondFloor")])
            let swimmers = ModelEntity(mesh: try Self.grid(pond, columns: 2, rows: 2) { _ in -Self.swimmerDepth * unit },
                                       materials: [try material("pondSwimmers", lit: false, transparent: true)])
            let water = ModelEntity(mesh: try Self.grid(pond, columns: 200, rows: 140) { _ in 0 },
                                    materials: [try material("pondSurface", waves: "pondWaves", transparent: true)])
            // Both see-through layers lie flat one above the other, so draw them deepest first.
            let group = ModelSortGroup()
            swimmers.components.set(ModelSortGroupComponent(group: group, order: 0))
            water.components.set(ModelSortGroupComponent(group: group, order: 1))
            models = [floor, swimmers, water]

            let eye = PerspectiveCamera()
            eye.camera.fieldOfViewInDegrees = Self.fieldOfView
            eye.look(at: .zero, from: camera.position, relativeTo: nil)
            let sun = DirectionalLight()
            sun.light.intensity = 3000
            sun.light.color = NSColor(srgbRed: 1, green: 0.96, blue: 0.88, alpha: 1)
            sun.look(at: .zero, from: Self.sunDirection * 10, relativeTo: nil)
            let root = Entity()
            ([eye, sun] + models).forEach { root.addChild($0) }
            renderer.entities.append(root)
            renderer.activeCamera = eye
            if let sky = Self.paintSky().makeImage() {
                renderer.lighting.resource = try EnvironmentResource(equirectangular: sky)
            }
            // Pixel art has no edges worth smoothing, and multisampling a whole display costs a lot.
            renderer.cameraSettings.antialiasing = .none
            renderer.cameraSettings.isToneMappingEnabled = false
            renderer.cameraSettings.colorBackground = .color(CGColor(srgbRed: 0.1, green: 0.2, blue: 0.18, alpha: 1))
        } catch {
            return nil
        }
    }

    /// Records the scene, moves the water on (unless it's a still) and draws the stage into `target`,
    /// then lays the scene's covers (the light of the time of day) over it before `completion`.
    func render(into target: MTLTexture, at date: Date = Date(), simulate: Bool = true, completion: (@Sendable (MTLCommandBuffer) -> Void)? = nil) {
        guard let commands = SceneRenderer.queue?.makeCommandBuffer() else { return }
        layers.record(scene, at: date)
        if layers.backdropVersion != floorVersion {
            layers.encodeBackdropCopy(into: floorTexture.replace(using: commands), commands: commands)
            floorVersion = layers.backdropVersion
        }
        layers.encodeLayers(swimming: swimming.replace(using: commands), floating: floating.replace(using: commands), commands: commands)
        if simulate { layers.encodeWater(surface, into: waves.replace(using: commands), commands: commands) }
        commands.commit()
        if waterColor != surface.color { tintWater(surface.color) }
        let covers = layers.covers
        let finish: @Sendable () -> Void = {
            guard let commands = SceneRenderer.queue?.makeCommandBuffer() else { return }
            SceneRenderer.encodeCovers(covers, over: target, commands: commands)
            completion?(commands)
            commands.commit()
        }
        do {
            let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: target))
            try renderer.updateAndRender(deltaTime: 1.0 / 30, cameraOutput: output, onComplete: { _ in finish() })
        } catch {
            finish()
        }
    }

    /// A still of the current frame, e.g. for the lock screen; the water doesn't move on for it.
    func snapshot(width: Int, height: Int) -> CGImage? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: Self.pixelFormat, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let texture = SceneRenderer.device?.makeTexture(descriptor: descriptor) else { return nil }
        let done = DispatchSemaphore(value: 0)
        render(into: texture, simulate: false) { commands in commands.addCompletedHandler { _ in done.signal() } }
        // The renderer may report back on the main thread, so keep it turning while waiting.
        let deadline = Date().addingTimeInterval(5)
        while done.wait(timeout: .now()) == .timedOut {
            guard Date() < deadline else { return nil }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        let image = PixelBuffer(width: width, height: height)
        image.pixels.withUnsafeMutableBytes { bytes in
            texture.getBytes(bytes.baseAddress!, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return image.makeImage()
    }

    /// The pond spot (0...1 across the pond) under a spot on the screen (0...1, origin top-left).
    func pondSpot(forViewSpot spot: Point) -> Point {
        let point = camera.water(at: spot)
        return Point(x: Double((point.x - pond.point(at: Point(x: 0, y: 0)).x) / pond.width), y: Double((point.z - pond.far) / pond.length))
    }

    /// Where a pond spot shows on the screen.
    func viewSpot(forPondSpot spot: Point) -> Point {
        camera.spot(of: pond.point(at: spot))
    }

    private func tintWater(_ color: Color) {
        waterColor = color
        let tint = NSColor(srgbRed: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255, blue: CGFloat(color.blue) / 255, alpha: 1)
        for model in models {
            guard var material = model.model?.materials.first as? CustomMaterial else { continue }
            material.baseColor.tint = tint
            model.model?.materials = [material]
        }
    }

    /// A flat grid over the pond and the margin around it, with the pond's 0...1 as texture coordinates
    /// and each vertex lifted to `height(spot)`.
    private static func grid(_ pond: Pond, columns: Int, rows: Int, height: (Point) -> Float) throws -> MeshResource {
        var positions: [SIMD3<Float>] = [], coordinates: [SIMD2<Float>] = [], indices: [UInt32] = []
        for row in 0...rows {
            for column in 0...columns {
                let spot = Point(x: Double(-margin + (1 + 2 * margin) * Float(column) / Float(columns)),
                                 y: Double(-margin + (1 + 2 * margin) * Float(row) / Float(rows)))
                positions.append(pond.point(at: spot, height: height(spot)))
                coordinates.append(SIMD2(Float(spot.x), Float(spot.y)))
            }
        }
        let stride = UInt32(columns + 1)
        for row in 0..<UInt32(rows) {
            for column in 0..<UInt32(columns) {
                let corner = row * stride + column
                indices += [corner, corner + stride, corner + 1, corner + 1, corner + stride, corner + stride + 1]
            }
        }
        var mesh = MeshDescriptor()
        mesh.positions = MeshBuffers.Positions(positions)
        mesh.textureCoordinates = MeshBuffers.TextureCoordinates(coordinates)
        mesh.primitives = .triangles(indices)
        return try MeshResource.generate(from: [mesh])
    }

    /// The sky the water reflects, as a panorama: blue overhead, paler towards the horizon, with soft clouds,
    /// and a ring of trees around the pond below the horizon.
    private static func paintSky() -> PixelBuffer {
        let width = 256, height = 128
        let sky = PixelBuffer(width: width, height: height)
        let zenith = Color(0x4f8fd0), horizon = Color(0xd8ecf0), trees = Color(0x2d4a30), ground = Color(0x1f3322)
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
