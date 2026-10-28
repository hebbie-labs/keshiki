import CoreGraphics
import Foundation

/// The koi pond sized for one display: the pond's world, its painted floor, and the canvas it's drawn into.
final class KoiPondScene: LivingScene {
    static let pixelWidth = 960.0

    let world: PondWorld
    private let canvas: PixelBuffer
    private let atmosphere = Atmosphere()
    private var floor: PixelBuffer
    private var floorWater: String
    private var time = 0.0
    var systemDark = false
    /// Called with the normalised spot whenever food is dropped, so the koi can learn your routine.
    var onFeed: ((Point) -> Void)?

    init(aspectRatio: Double, settings: KeshikiSettings, options: KoiPondSettings = KoiPondSettings()) {
        let size = SceneSize(width: Self.pixelWidth, height: (Self.pixelWidth / max(aspectRatio, 0.1)).rounded())
        self.settings = settings
        world = PondWorld(size: size, options: options)
        world.raining = settings.rain
        canvas = PixelBuffer(width: Int(size.width), height: Int(size.height))
        floor = PondFloor.paint(size: size, waterName: options.water)
        floorWater = options.water
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

    func advance(by dt: Double) {
        time += dt
        world.update(dt: dt)
    }

    func render(at date: Date) -> CGImage? {
        canvas.copyPixels(from: floor)
        world.draw(on: canvas, time: time)
        let timeOfDay = TimeOfDay.current(theme: settings.theme, systemDark: systemDark, date: date)
        atmosphere.draw(on: canvas, size: world.size, timeOfDay: timeOfDay, raining: settings.rain, time: time)
        return canvas.makeImage()
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

    /// Converts a 0...1 position on the display into pond pixels.
    func pondPoint(fromNormalized point: Point) -> Point {
        Point(x: point.x * world.size.width, y: point.y * world.size.height)
    }

    private func repaintFloorIfWaterChanged() {
        guard options.water != floorWater else { return }
        floor = PondFloor.paint(size: world.size, waterName: options.water)
        floorWater = options.water
    }
}
