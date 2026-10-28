import Foundation

enum Visitor: String {
    case goose, ball, clear
}

/// Everything living in one pond, and the order it's drawn in.
final class PondWorld {
    let size: SceneSize
    var options: KoiPondSettings
    var raining = false
    let pads: [LilyPad]
    var duckweed: [DuckweedLeaf]
    let schools: [FishSchool]
    let frog: Frog
    private(set) var kois: [Koi] = []
    var food: [FoodPellet] = []
    let water: WaterSurface
    private(set) var goose: Goose?
    private(set) var ball: Ball?
    private(set) var greetingSpot: Point?
    var usualSpot: Point?

    private static let koiCount = 8
    /// The floor lies this deep at the edges and this much deeper in the middle, in design units.
    private static let shallowDepth = 8.0
    private static let depthRange = 52.0

    init(size: SceneSize, options: KoiPondSettings) {
        self.size = size
        self.options = options
        pads = LilyPad.scatter(in: size)
        water = WaterSurface(obstacles: pads.map { WaterSurface.Disc(center: $0.center, radius: $0.radius) },
                             depth: { [size] in Self.shallowDepth + Self.depthRange * PondFloor.depth(x: $0.x, y: $0.y, size: size) })
        duckweed = PondWorld.scatterDuckweed(in: size)
        schools = [.himedaka, .tanago, .oikawa, .motsugo].map { FishSchool(species: $0, in: size) }
        frog = Frog(pad: pads[0])
        kois = (0..<Self.koiCount).map { Koi(index: $0, in: size) }
    }

    /// The school the "tiny fish" koi likes to herd.
    var herdedSchool: FishSchool { schools[0] }

    func update(dt: Double) {
        sinkOldFood(dt: dt)
        regrowDuckweed(dt: dt)
        schools.forEach { $0.update(in: self, dt: dt) }
        kois.forEach { $0.update(in: self, dt: dt) }
        frog.update(in: self, dt: dt)
        if let goose, !goose.update(in: self, dt: dt) { self.goose = nil }
        ball?.update(in: self, dt: dt)
        if raining { addRaindrops() }
    }

    /// What swims below, then what floats on top. The floor is the backdrop; the water casts the shadows
    /// and the scene adds the sky.
    func draw(on canvas: Canvas, time: Double) {
        schools.forEach { $0.draw(on: canvas) }
        kois.forEach { $0.draw(on: canvas) }
        canvas.placeSurface()
        drawFood(on: canvas)
        drawDuckweed(on: canvas)
        canvas.placeOverlay()
        frog.draw(on: canvas, time: time)
        ball?.draw(on: canvas)
        goose?.draw(on: canvas, time: time)
    }

    func touchWater(at point: Point) {
        addRipple(at: point)
        if options.callOnClick { kois.forEach { $0.call(to: point) } }
    }

    func invite(_ visitor: Visitor) {
        switch visitor {
        case .goose:
            if goose == nil { goose = Goose(in: size) }
        case .ball:
            let position = size.randomPoint(marginX: 120, marginY: 100)
            ball = Ball(at: position)
            addRipple(at: position, radius: 8, strength: 1.5)
        case .clear:
            goose?.leave()
            ball = nil
        }
    }

    /// The koi gather at a spot (the morning greeting) until `scatter()`.
    func gather(at spot: Point) {
        greetingSpot = spot
        kois.forEach { $0.lookAround() }
    }

    func scatter() {
        greetingSpot = nil
        kois.forEach { $0.lookAround() }
    }
}
