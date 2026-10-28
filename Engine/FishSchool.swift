import Foundation

/// A school of small fish that drifts around and scatters from the koi, so a koi can herd it.
final class FishSchool {
    struct Species {
        let back: Color
        let belly: Color
        let fin: Color
        let length: Int
        let count: Int
        let speed: Double

        static let ember = Species(back: Color(0xe0412f), belly: Color(0xff9a7a), fin: Color(0xff6f8a), length: 10, count: 16, speed: 1)
        static let neon = Species(back: Color(0x2f86e8), belly: Color(0xa8ecff), fin: Color(0x1c4fae), length: 10, count: 11, speed: 1.15)
        static let citrus = Species(back: Color(0xd9b52c), belly: Color(0xf6e27a), fin: Color(0x7fb83a), length: 11, count: 6, speed: 0.85)
    }

    private struct Fish {
        var position: Point
        var velocity = Point(x: 0, y: 0)
        var tailPhase = random(0...6.28)
    }

    let species: Species
    private(set) var center: Point
    private var destination: Point
    private var fish: [Fish]

    private static let scareRadius = 40.0
    private static let damping = 0.93
    private static let personalSpace = 9.0
    private static let shadow = Color(0x0b2e26, alpha: 0.22)

    init(species: Species, in size: PondSize) {
        self.species = species
        center = size.randomPoint(marginX: 100, marginY: 80)
        destination = center
        fish = (0..<species.count).map { [center] _ in Fish(position: center.jittered(20)) }
    }

    func update(in world: World, dt: Double) {
        if destination.distance(to: center) < 10 { destination = world.size.randomPoint(marginX: 60, marginY: 50) }
        center.x += (destination.x - center.x) * 0.004 * dt * 60
        center.y += (destination.y - center.y) * 0.004 * dt * 60
        for index in fish.indices {
            keepDistance(index)
            swim(&fish[index], in: world, dt: dt)
        }
        recenter()
    }

    func draw(on canvas: PixelBuffer) {
        for member in fish { drawFish(member, on: canvas) }
    }

    private func swim(_ member: inout Fish, in world: World, dt: Double) {
        let wander = species.speed * 0.08
        member.velocity.x += (center.x - member.position.x) * 0.002 + random(-wander...wander)
        member.velocity.y += (center.y - member.position.y) * 0.002 + random(-wander...wander)
        for koi in world.kois { flee(&member, from: koi.head, in: world.size) }
        member.velocity.x *= Self.damping
        member.velocity.y *= Self.damping
        member.position = world.size.clamped(Point(x: member.position.x + member.velocity.x * dt * 60,
                                                   y: member.position.y + member.velocity.y * dt * 60), margin: 3)
        member.tailPhase += dt * (6 + hypot(member.velocity.x, member.velocity.y) * 10)
    }

    /// Small fish keep a body length apart, so the school stays a loose cloud.
    private func keepDistance(_ index: Int) {
        for other in fish.indices where other != index {
            let gap = fish[index].position.distance(to: fish[other].position)
            guard gap < Self.personalSpace, gap > 0 else { continue }
            fish[index].velocity.x += (fish[index].position.x - fish[other].position.x) / gap * 0.05
            fish[index].velocity.y += (fish[index].position.y - fish[other].position.y) / gap * 0.05
        }
    }

    private func flee(_ member: inout Fish, from predator: Point, in size: PondSize) {
        let distance = predator.distance(to: member.position)
        guard distance < Self.scareRadius, distance > 0 else { return }
        let away = Point(x: (member.position.x - predator.x) / distance, y: (member.position.y - predator.y) / distance)
        member.velocity.x += away.x * 0.35
        member.velocity.y += away.y * 0.35
        destination = size.clamped(Point(x: member.position.x + away.x * 120, y: member.position.y + away.y * 120), margin: 40)
    }

    private func recenter() {
        let count = Double(fish.count)
        let average = Point(x: fish.map(\.position.x).reduce(0, +) / count, y: fish.map(\.position.y).reduce(0, +) / count)
        center.x += (average.x - center.x) * 0.02
        center.y += (average.y - center.y) * 0.02
    }

    /// Head to tail along the swimming direction: two pixels wide in the middle, a flicking tail fin at the end.
    private func drawFish(_ member: Fish, on canvas: PixelBuffer) {
        let heading = hypot(member.velocity.x, member.velocity.y) > 0.01 ? atan2(member.velocity.y, member.velocity.x) : 0
        let side = heading + .pi / 2
        let length = species.length
        for step in 0..<length - 2 { canvas.plot(member.position.moved(by: -Double(step), heading: heading).moved(by: 6, heading: 0.9), Self.shadow) }
        for step in 0..<length {
            let point = member.position.moved(by: -Double(step), heading: heading)
            let flick = sin(member.tailPhase) * 0.8 * Double(step) / Double(length)
            switch step {
            case 0:
                canvas.plot(point, species.back)
                canvas.plot(point.moved(by: 1, heading: side), species.belly)
            case length - 1:
                canvas.plot(point.moved(by: 1.5 + flick, heading: side), species.fin)
                canvas.plot(point.moved(by: -1.5 + flick, heading: side), species.fin)
            case length - 2:
                canvas.plot(point.moved(by: flick, heading: side), species.fin)
            default:
                let body = point.moved(by: flick, heading: side)
                canvas.plot(body, species.back)
                canvas.plot(body.moved(by: 1, heading: side), species.belly)
                if step >= 1 && step <= length / 2 + 1 { canvas.plot(body.moved(by: -1, heading: side), species.back) }
            }
        }
    }
}
