import Foundation

enum Visitor: String {
    case goose, ball, clear
}

/// Everything living in one pond, and the order it's drawn in.
final class PondWorld {
    let size: SceneSize
    var options: KoiPondSettings
    var raining = false
    var pads: [LilyPad]
    var duckweed: [DuckweedLeaf]
    var seagrass: [SeagrassTuft]
    private(set) var schools: [FishSchool]
    let frog: Frog
    private(set) var kois: [Koi] = []
    var food: [FoodPellet] = []
    var droplets: [Droplet] = []
    let water: WaterSurface
    private(set) var goose: Goose?
    private(set) var ball: Ball?
    private(set) var greetingSpot: Point?
    /// Where this pond opens into the ponds of neighbouring displays (`PondLinks`).
    var openings: [Opening] = []
    /// Called with a spot the user clicked, to call the koi of neighbouring ponds too.
    var onCall: ((Point) -> Void)?
    var usualSpot: Point?
    /// Seconds the pond has been running.
    private(set) var clock = 0.0

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
        seagrass = PondWorld.plantSeagrass(in: size)
        schools = [.himedaka, .tanago, .oikawa, .motsugo].map { FishSchool(species: $0, in: size) }
        frog = Frog()
        kois = (0..<Self.koiCount).map { Koi(index: $0, in: size) }
    }

    /// The school the "tiny fish" koi likes to herd.
    /// Nil once every school swam over to a neighbouring pond.
    var herdedSchool: FishSchool? { schools.first }

    func update(dt: Double) {
        clock += dt
        sinkOldFood(dt: dt)
        regrowDuckweed(dt: dt)
        moveFloating(dt: dt)
        moveSeagrass(dt: dt)
        moveDroplets(dt: dt)
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
        drawSeagrass(on: canvas)
        schools.forEach { $0.draw(on: canvas, visibility: visibility(at: $0.center)) }
        kois.forEach { $0.draw(on: canvas, visibility: visibility(at: $0.head)) }
        canvas.placeSurface()
        drawFood(on: canvas)
        drawDuckweed(on: canvas)
        pads.forEach { $0.draw(on: canvas) }
        frog.draw(on: canvas, time: time, pads: pads)
        ball?.draw(on: canvas)
        goose?.draw(on: canvas, time: time)
        drawDroplets(on: canvas)
    }

    func touchWater(at point: Point) {
        addRipple(at: point)
        if options.callOnClick {
            kois.forEach { $0.call(to: point) }
            onCall?(point)
        }
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

    // Swimming over to a neighbouring pond (`PondLinks`).
    func release(_ koi: Koi) { kois.removeAll { $0 === koi } }
    func adopt(_ koi: Koi) {
        kois.append(koi)
        koi.lookAround()
    }
    func release(_ school: FishSchool) { schools.removeAll { $0 === school } }
    func adopt(_ school: FishSchool) { schools.append(school) }
    func release(_ goose: Goose) { if self.goose === goose { self.goose = nil } }
    func adopt(_ goose: Goose) {
        self.goose = goose
        goose.arrive(in: size)
    }
    func release(_ ball: Ball) { if self.ball === ball { self.ball = nil } }
    func adopt(_ ball: Ball) { self.ball = ball }

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
