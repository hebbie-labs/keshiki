import Foundation

/// The koi pond sized for one display: the pond's world and its painted floor.
final class KoiPondScene: LivingScene {
    let pixelScale = 1.5

    let world: PondWorld
    private let atmosphere = Atmosphere()
    private var newFloor: PixelBuffer?
    private var newReeds: Standing?
    private var floorWater: String
    private var time = 0.0
    var systemDark = false
    /// Called with the normalised spot whenever food is dropped, so the koi can learn your routine.
    var onFeed: ((Point) -> Void)?

    init(aspectRatio: Double, settings: KeshikiSettings, options: KoiPondSettings = KoiPondSettings(), width: Double = 960) {
        let size = SceneSize(width: width.rounded(), height: (width / max(aspectRatio, 0.1)).rounded())
        self.settings = settings
        world = PondWorld(size: size, options: options)
        world.raining = settings.rain
        floorWater = options.water
        newFloor = PondFloor.paint(size: size, scale: pixelScale, waterName: options.water)
        newReeds = Reeds.make(size: size, scale: pixelScale)
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

    var water: WaterSurface? { world.water }

    func advance(by dt: Double) {
        time += dt
        world.update(dt: dt)
    }

    func takeNewBackdrop() -> PixelBuffer? {
        defer { newFloor = nil }
        return newFloor
    }

    func takeNewStanding() -> Standing? {
        defer { newReeds = nil }
        return newReeds
    }

    /// Everything floating moves, so it's all drawn each frame.
    func takeNewOverlay() -> PixelBuffer? { nil }

    func draw(on canvas: Canvas, at date: Date) {
        world.draw(on: canvas, time: time)
        let timeOfDay = TimeOfDay.current(theme: settings.theme, systemDark: systemDark, date: date)
        world.water.color = timeOfDay.water.mixed(with: WaterPalette.named(options.water).deepWater, 0.25)
        world.water.glow = timeOfDay.glow
        world.water.sunlight = timeOfDay.sunlight
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
        newFloor = PondFloor.paint(size: world.size, scale: pixelScale, waterName: options.water)
        floorWater = options.water
    }
}
