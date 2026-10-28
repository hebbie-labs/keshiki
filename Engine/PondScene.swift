import CoreGraphics
import Foundation

/// One pond sized for one display: the world, its painted floor, and the canvas it's drawn into.
final class PondScene {
    static let pixelWidth = 960.0

    let world: World
    private let canvas: PixelBuffer
    private var floor: PixelBuffer
    private var floorWater: String
    private(set) var time = 0.0
    var systemDark = false

    init(aspectRatio: Double, settings: PondSettings) {
        let size = PondSize(width: Self.pixelWidth, height: (Self.pixelWidth / max(aspectRatio, 0.1)).rounded())
        world = World(size: size, settings: settings)
        canvas = PixelBuffer(width: Int(size.width), height: Int(size.height))
        floor = PondFloor.paint(size: size, waterName: settings.water)
        floorWater = settings.water
    }

    var settings: PondSettings {
        get { world.settings }
        set {
            world.settings = newValue
            repaintFloorIfWaterChanged()
        }
    }

    func advance(by dt: Double) {
        time += dt
        world.update(dt: dt)
    }

    func render(at date: Date = Date()) -> CGImage? {
        canvas.copyPixels(from: floor)
        let timeOfDay = TimeOfDay.current(theme: settings.theme, systemDark: systemDark, date: date)
        world.draw(on: canvas, time: time, timeOfDay: timeOfDay)
        return canvas.makeImage()
    }

    /// Converts a 0...1 position on the display into pond pixels.
    func pondPoint(fromNormalized point: Point) -> Point {
        Point(x: point.x * world.size.width, y: point.y * world.size.height)
    }

    private func repaintFloorIfWaterChanged() {
        guard settings.water != floorWater else { return }
        floor = PondFloor.paint(size: world.size, waterName: settings.water)
        floorWater = settings.water
    }
}
