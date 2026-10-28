import Foundation

/// The koi pond sized for one display: the pond's world and its painted floor.
final class KoiPondScene: LivingScene {
    static let designWidth = 960.0
    let pixelScale = 1.5

    let world: PondWorld
    private let atmosphere = Atmosphere()
    private var newFloor: PixelBuffer?
    private var newOverlay: PixelBuffer?
    private var floorWater: String
    private var time = 0.0
    var systemDark = false
    /// Called with the normalised spot whenever food is dropped, so the koi can learn your routine.
    var onFeed: ((Point) -> Void)?

    init(aspectRatio: Double, settings: KeshikiSettings, options: KoiPondSettings = KoiPondSettings()) {
        let size = SceneSize(width: Self.designWidth, height: (Self.designWidth / max(aspectRatio, 0.1)).rounded())
        self.settings = settings
        world = PondWorld(size: size, options: options)
        world.raining = settings.rain
        floorWater = options.water
        newFloor = PondFloor.paint(size: size, scale: pixelScale, waterName: options.water, pads: world.pads)
        newOverlay = paintLilyPads()
    }

    var settings: KeshikiSettings {
        didSet { world.raining = settings.rain }
    }

    var options: KoiPondSettings {
        get { world.options }
        set {
            world.options = newValue
            repaintFloorIfWaterChanged()
        }
    }

    var pixelWidth: Int { Int((world.size.width * pixelScale).rounded()) }
    var pixelHeight: Int { Int((world.size.height * pixelScale).rounded()) }

    var caustics: CausticsFrame? { Caustics.frame(at: time) }

    func advance(by dt: Double) {
        time += dt
        world.update(dt: dt)
    }

    func takeNewBackdrop() -> PixelBuffer? {
        defer { newFloor = nil }
        return newFloor
    }

    func takeNewOverlay() -> PixelBuffer? {
        defer { newOverlay = nil }
        return newOverlay
    }

    func draw(on canvas: Canvas, at date: Date) {
        world.draw(on: canvas, time: time)
        let timeOfDay = TimeOfDay.current(theme: settings.theme, systemDark: systemDark, date: date)
        atmosphere.draw(on: canvas, size: world.size, timeOfDay: timeOfDay, raining: settings.rain, time: time)
    }

    func touch(at spot: Point, withOption: Bool) {
        let point = pondPoint(fromNormalized: spot)
        if !withOption {
            world.touchWater(at: point)
        } else if options.feedOnAlt {
            world.dropFood(at: point)
            onFeed?(spot)
        }
    }

    /// Converts a 0...1 position on the display into pond coordinates.
    func pondPoint(fromNormalized point: Point) -> Point {
        Point(x: point.x * world.size.width, y: point.y * world.size.height)
    }

    private func repaintFloorIfWaterChanged() {
        guard options.water != floorWater else { return }
        newFloor = PondFloor.paint(size: world.size, scale: pixelScale, waterName: options.water, pads: world.pads)
        floorWater = options.water
    }

    /// The lily pads float above the fish and never move, so they're painted once into a transparent layer.
    private func paintLilyPads() -> PixelBuffer {
        let overlay = PixelBuffer(width: pixelWidth, height: pixelHeight, scale: pixelScale, color: nil)
        world.pads.forEach { $0.draw(on: overlay) }
        return overlay
    }
}
