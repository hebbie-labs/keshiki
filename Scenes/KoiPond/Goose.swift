import Foundation

/// Swims in from an edge, potters around for a while, then leaves again.
final class Goose {
    private(set) var position: Point
    private(set) var heading: Double
    private var staysFor = random(60...120)
    private(set) var isLeaving = false
    private var destination: Point
    private var paddleTimer = 0.0

    private static let scale = 1.6
    private static let speed = 0.6
    private static let turnRate = 0.02
    private static let paddleEverySeconds = 0.6
    private static let white = Color(0xf6f4ee)

    init(in size: SceneSize) {
        position = Goose.pointOffEdge(of: size)
        heading = position.heading(to: size.center)
        destination = size.randomPoint(marginX: 100, marginY: 80)
    }

    /// A spot just behind the goose, for koi that like to follow it.
    var spotBehind: Point { position.moved(by: -30, heading: heading) }

    func leave() {
        staysFor = 0
    }

    /// Returns false once the goose has swum off screen.
    func update(in world: PondWorld, dt: Double) -> Bool {
        staysFor -= dt
        chooseDestination(in: world.size)
        heading += clamp(angleDifference(from: heading, to: position.heading(to: destination)), -Self.turnRate, Self.turnRate) * dt * 60
        position = position.moved(by: Self.speed * dt * 60, heading: heading)
        paddle(in: world, dt: dt)
        return !(isLeaving && !world.size.contains(position, margin: 40))
    }

    func draw(on canvas: PixelBuffer, time: Double) {
        let along = Point(x: cos(heading) * Self.scale, y: sin(heading) * Self.scale)
        drawBody(on: canvas, along: along)
        drawNeckAndHead(on: canvas, along: along, bend: sin(time * 1.3) * 0.25)
    }

    private func chooseDestination(in size: SceneSize) {
        if staysFor <= 0 && !isLeaving {
            isLeaving = true
            destination = Goose.pointOffEdge(of: size)
        }
        if !isLeaving && position.distance(to: destination) < 15 { destination = size.randomPoint(marginX: 100, marginY: 80) }
    }

    private func paddle(in world: PondWorld, dt: Double) {
        paddleTimer += dt
        guard paddleTimer >= Self.paddleEverySeconds else { return }
        paddleTimer = 0
        world.addRipple(at: position.moved(by: -14, heading: heading), radius: 3, life: 0.6)
    }

    private func drawBody(on canvas: PixelBuffer, along: Point) {
        func spine(_ i: Double) -> Point { Point(x: position.x + along.x * i * 3, y: position.y + along.y * i * 3) }
        for i in -3...3 {
            let point = spine(Double(i))
            canvas.disc(Point(x: point.x + 8, y: point.y + 11), radius: 16 - Double(abs(i)) * 1.6, Color(0x0b2e26, alpha: 0.3))
        }
        for i in -4...3 { canvas.disc(spine(Double(i)), radius: 16 - Double(abs(i)) * 1.3, i < -2 ? Color(0xd9d6cc) : Self.white) }
        for side in [-1.0, 1.0] {
            for i in -2...2 {
                let point = spine(Double(i))
                canvas.disc(Point(x: point.x - along.y * side * 6, y: point.y + along.x * side * 6), radius: 6, Color(0xe3e0d6))
            }
        }
    }

    private func drawNeckAndHead(on canvas: PixelBuffer, along: Point, bend: Double) {
        let neckHeading = heading + bend
        var point = Point(x: position.x + along.x * 10, y: position.y + along.y * 10)
        for _ in 0..<5 {
            point = point.moved(by: 3 * Self.scale, heading: neckHeading)
            canvas.disc(point, radius: 4, Self.white)
        }
        canvas.disc(point, radius: 6, Self.white)
        canvas.disc(point.moved(by: 5 * Self.scale, heading: neckHeading), radius: 3, Color(0xf08a24))
        for side in [-1.0, 1.0] { canvas.fillRect(point.moved(by: 4, heading: neckHeading + side * 1.3), width: 2, height: 2, Color(0x111111)) }
    }

    private static func pointOffEdge(of size: SceneSize) -> Point {
        [Point(x: -30, y: random(60...(size.height - 60))),
         Point(x: size.width + 30, y: random(60...(size.height - 60))),
         Point(x: random(60...(size.width - 60)), y: -30),
         Point(x: random(60...(size.width - 60)), y: size.height + 30)].randomElement()!
    }
}
