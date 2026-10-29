import Foundation

/// The koi pond sized for one display: the pond's world and its painted floor.
final class KoiPondScene: LivingScene {
    /// Two device pixels per design unit: finer than the pixel art needs, still light on the GPU. On battery 1.5,
    /// which costs about a third less. The display scales the frame up smoothly to its own resolution.
    let pixelScale = SystemConditions.isOnBattery ? 1.5 : 2.0

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
            replantIfWaterChanged()
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
        // The water's own colour, darkened like the light of the time of day, so night stays night.
        let palette = WaterPalette.named(options.water)
        world.water.color = timeOfDay.water.mixed(with: palette.water.mixed(with: Color(0x000000), (1 - timeOfDay.sunlight) * 0.7), 0.7)
        world.water.murk = palette.murk
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

    private func replantIfWaterChanged() {
        guard options.water != floorWater else { return }
        newFloor = PondFloor.paint(size: world.size, scale: pixelScale, waterName: options.water)
        world.rosettes = PondWorld.plantRosettes(in: world.size, waterName: options.water)
        floorWater = options.water
    }
}
