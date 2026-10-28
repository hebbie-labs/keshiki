import Foundation

enum Visitor: String {
    case goose, ball, clear
}

/// Everything living in one pond, and the order it's drawn in.
final class World {
    let size: PondSize
    var settings: PondSettings
    let pads: [LilyPad]
    var duckweed: [DuckweedLeaf]
    let schools: [FishSchool]
    let frog: Frog
    private(set) var kois: [Koi] = []
    var food: [FoodPellet] = []
    var ripples: [Ripple] = []
    var fireflies: [Firefly] = []
    private(set) var goose: Goose?
    private(set) var ball: Ball?
    private(set) var greetingSpot: Point?
    var usualSpot: Point?

    private static let koiCount = 8

    init(size: PondSize, settings: PondSettings) {
        self.size = size
        self.settings = settings
        pads = LilyPad.scatter(in: size)
        duckweed = World.scatterDuckweed(in: size)
        schools = [.ember, .neon, .citrus].map { FishSchool(species: $0, in: size) }
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
        if settings.rain { addRaindrops() }
        updateRipples(dt: dt)
    }

    /// Floor light first, then what swims below, what floats on top, and finally the sky's tint.
    func draw(on canvas: PixelBuffer, time: Double, timeOfDay: TimeOfDay) {
        Caustics.draw(on: canvas, time: time)
        kois.forEach { $0.drawShadow(on: canvas) }
        pads.forEach { $0.drawShadow(on: canvas, time: time) }
        schools.forEach { $0.draw(on: canvas) }
        kois.forEach { $0.draw(on: canvas) }
        drawFood(on: canvas)
        drawDuckweed(on: canvas)
        pads.forEach { $0.draw(on: canvas, time: time) }
        frog.draw(on: canvas, time: time)
        ball?.draw(on: canvas)
        goose?.draw(on: canvas, time: time)
        drawRipples(on: canvas)
        Sky.draw(on: canvas, world: self, timeOfDay: timeOfDay, time: time)
    }

    func touchWater(at point: Point) {
        addRipple(at: point)
        if settings.callOnClick { kois.forEach { $0.call(to: point) } }
    }

    func invite(_ visitor: Visitor) {
        switch visitor {
        case .goose:
            if goose == nil { goose = Goose(in: size) }
        case .ball:
            let position = size.randomPoint(marginX: 120, marginY: 100)
            ball = Ball(at: position)
            for ring in 0..<3 { addRipple(at: position, radius: 2 + Double(ring) * 4) }
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
