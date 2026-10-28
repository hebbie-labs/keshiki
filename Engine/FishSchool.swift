import Foundation

/// A loose school of small Japanese pond fish. Each fish swims with a heading and speed of its own,
/// turning smoothly towards its place in the school and darting off when a koi comes close.
final class FishSchool {
    /// Seen from above: a darker back along the spine, lighter flanks, and the species' markings.
    struct Species {
        let back: Color
        let flank: Color
        let fin: Color
        let marking: Color
        let markingStyle: MarkingStyle
        let length: Int
        let halfWidth: Double
        let count: Int
        let cruiseSpeed: Double

        enum MarkingStyle {
            case none          // himedaka: plain orange
            case shoulderSpot  // tanago: a blue spot behind the head
            case crossBars     // oikawa: blue-green bars across the back
            case spineStripe   // motsugo: a dark line down the back
        }

        /// Hime-medaka, the orange rice fish kept in Japanese pots and ponds.
        static let himedaka = Species(back: Color(0xe0702a), flank: Color(0xf6a64c), fin: Color(0xf8c88a, alpha: 0.7),
                                      marking: Color(0xe0702a), markingStyle: .none,
                                      length: 12, halfWidth: 1.6, count: 14, cruiseSpeed: 0.4)
        /// Tanago, a bitterling with rosy flanks and a blue shoulder spot.
        static let tanago = Species(back: Color(0x5f6f98), flank: Color(0xc9b4d6), fin: Color(0xe8789e, alpha: 0.8),
                                    marking: Color(0x2f62c8), markingStyle: .shoulderSpot,
                                    length: 13, halfWidth: 2.0, count: 9, cruiseSpeed: 0.35)
        /// Oikawa, the pale chub: slender and fast, with soft blue-green bars and pink fins.
        static let oikawa = Species(back: Color(0x4a8274), flank: Color(0xdce6de), fin: Color(0xec8c92, alpha: 0.8),
                                    marking: Color(0x7dbcc8), markingStyle: .crossBars,
                                    length: 16, halfWidth: 1.7, count: 6, cruiseSpeed: 0.5)
        /// Motsugo, the stone moroko: olive back with a dark stripe.
        static let motsugo = Species(back: Color(0x6b6a50), flank: Color(0xc6c2a2), fin: Color(0xb8b496, alpha: 0.6),
                                     marking: Color(0x4d4c3c), markingStyle: .spineStripe,
                                     length: 12, halfWidth: 1.6, count: 10, cruiseSpeed: 0.38)
    }

    private struct Fish {
        var position: Point
        var heading = random(0...(2 * .pi))
        var speed = 0.0
        var turning = 0.0
        var tailPhase = random(0...(2 * .pi))
        /// Where in the school this fish likes to be, relative to the school's centre.
        var slot: Point
        var nextBurstIn = random(0...2)
    }

    let species: Species
    private(set) var center: Point
    private var destination: Point
    /// The direction the whole school is drifting; fish that are in place swim along with it.
    private var heading = 0.0
    private var fish: [Fish]

    private static let scareRadius = 45.0
    private static let personalSpace = 10.0
    private static let turnRate = 0.045
    private static let burstSeconds = 1.5...4.0
    private static let shadowOffset = Point(x: 7, y: 9)
    private static let shadow = Color(0x0b2e26, alpha: 0.2)
    private static let eye = Color(0x161616)

    init(species: Species, in size: PondSize) {
        self.species = species
        center = size.randomPoint(marginX: 100, marginY: 80)
        destination = center
        let spread = Double(species.count).squareRoot() * 9
        fish = (0..<species.count).map { [center] _ in
            let slot = Point(x: 0, y: 0).jittered(spread, spread * 0.7)
            return Fish(position: Point(x: center.x + slot.x, y: center.y + slot.y), slot: slot)
        }
    }

    func update(in world: World, dt: Double) {
        wander(in: world.size, dt: dt)
        for index in fish.indices { swim(index, in: world, dt: dt) }
    }

    func draw(on canvas: PixelBuffer) {
        for member in fish { draw(member, on: canvas) }
    }

    // MARK: - Movement

    /// The school as a whole drifts slowly from one spot to the next.
    private func wander(in size: PondSize, dt: Double) {
        if destination.distance(to: center) < 12 { destination = size.randomPoint(marginX: 70, marginY: 60) }
        let step = min(1, 0.006 * dt * 60)
        center.x += (destination.x - center.x) * step * 0.4
        center.y += (destination.y - center.y) * step * 0.4
        heading += angleDifference(from: heading, to: center.heading(to: destination)) * 0.02
    }

    private func swim(_ index: Int, in world: World, dt: Double) {
        var member = fish[index]
        let threat = nearestKoi(to: member.position, in: world)
        let wanted = threat.map { awayFrom($0, member) } ?? towardsSlot(member, index: index)

        let turn = clamp(angleDifference(from: member.heading, to: wanted.heading), -Self.turnRate, Self.turnRate) * dt * 60
        member.heading += turn
        member.turning += (turn - member.turning) * 0.2

        member.nextBurstIn -= dt
        var targetSpeed = species.cruiseSpeed * wanted.urgency
        if member.nextBurstIn <= 0 {
            // Small fish swim in little bursts and glide in between.
            targetSpeed *= 1.5
            if member.nextBurstIn < -0.25 { member.nextBurstIn = random(Self.burstSeconds) }
        }
        member.speed += (targetSpeed - member.speed) * (targetSpeed > member.speed ? 0.18 : 0.04)
        member.position = world.size.clamped(member.position.moved(by: member.speed * dt * 60, heading: member.heading), margin: 4)
        member.tailPhase += dt * (4 + member.speed * 14)
        fish[index] = member

        if let threat { destination = world.size.clamped(threat.moved(by: -140, heading: threat.heading(to: member.position) + .pi), margin: 50) }
    }

    /// Head for its place in the school, nudged away from neighbours that are too close.
    private func towardsSlot(_ member: Fish, index: Int) -> (heading: Double, urgency: Double) {
        let slot = Point(x: center.x + member.slot.x, y: center.y + member.slot.y)
        var direction = Point(x: slot.x - member.position.x, y: slot.y - member.position.y)
        let distance = max(1, hypot(direction.x, direction.y))
        direction = Point(x: direction.x / distance, y: direction.y / distance)
        for other in fish.indices where other != index {
            let gap = member.position.distance(to: fish[other].position)
            guard gap < Self.personalSpace, gap > 0 else { continue }
            direction.x += (member.position.x - fish[other].position.x) / gap * 0.6
            direction.y += (member.position.y - fish[other].position.y) / gap * 0.6
        }
        // In place, a fish swims along with the school instead of circling its spot.
        let alignment = clamp(1 - distance / 20, 0, 1) * 1.5
        direction.x += cos(heading) * alignment
        direction.y += sin(heading) * alignment
        let urgency = clamp(distance / 25, 0.3, 1.2)
        return (atan2(direction.y, direction.x), urgency)
    }

    private func awayFrom(_ threat: Point, _ member: Fish) -> (heading: Double, urgency: Double) {
        (threat.heading(to: member.position), 2.8)
    }

    private func nearestKoi(to point: Point, in world: World) -> Point? {
        world.kois.map(\.head).filter { $0.distance(to: point) < Self.scareRadius }.min { $0.distance(to: point) < $1.distance(to: point) }
    }

    // MARK: - Drawing

    /// The spine bends with the turn and ripples towards the tail as the fish swims.
    private func spine(of member: Fish) -> [(point: Point, direction: Double)] {
        var point = member.position
        var result: [(Point, Double)] = []
        for step in 0..<species.length {
            let t = Double(step) / Double(species.length - 1)
            let wave = sin(member.tailPhase - t * 4) * t * t * 0.9
            let direction = member.heading - member.turning * t * 6 + wave
            result.append((point, direction))
            point = point.moved(by: -1, heading: direction)
        }
        return result
    }

    /// Widest just behind the head, tapering into the tail.
    private func halfWidth(at t: Double) -> Double {
        let profile = t < 0.25 ? 0.6 + t / 0.25 * 0.4 : max(0.25, 1 - (t - 0.25) / 0.6)
        return species.halfWidth * profile
    }

    private func draw(_ member: Fish, on canvas: PixelBuffer) {
        let points = spine(of: member)
        let bodyEnd = species.length - 3
        for (step, segment) in points.enumerated() where step < bodyEnd {
            canvas.plot(Point(x: segment.point.x + Self.shadowOffset.x, y: segment.point.y + Self.shadowOffset.y), Self.shadow)
        }
        drawTail(points, from: bodyEnd, on: canvas)
        drawPectoralFins(points, on: canvas)
        // Solid discs along the spine (and between points), so a diagonal fish has no gaps.
        for (step, segment) in points.prefix(bodyEnd).enumerated() {
            let half = halfWidth(at: Double(step) / Double(species.length - 1))
            canvas.disc(segment.point, radius: half + 0.4, species.flank)
            guard step + 1 < bodyEnd else { continue }
            let next = points[step + 1].point
            canvas.disc(Point(x: (segment.point.x + next.x) / 2, y: (segment.point.y + next.y) / 2), radius: half + 0.3, species.flank)
        }
        for (step, segment) in points.prefix(bodyEnd).enumerated() {
            if step >= 1 && step < bodyEnd - 1 { canvas.plot(segment.point, species.back) }
            drawMarking(at: segment.point, across: segment.direction + .pi / 2, step: step,
                        half: halfWidth(at: Double(step) / Double(species.length - 1)), on: canvas)
        }
        for side in [-1.0, 1.0] { canvas.plot(points[1].point.moved(by: side * species.halfWidth * 0.8, heading: points[1].direction + .pi / 2), Self.eye) }
    }

    private func drawTail(_ points: [(point: Point, direction: Double)], from start: Int, on canvas: PixelBuffer) {
        for step in start..<species.length {
            let spread = Double(step - start) + 0.5
            let segment = points[step]
            for side in [-1.0, 1.0] { canvas.plot(segment.point.moved(by: side * spread, heading: segment.direction + .pi / 2), species.fin) }
        }
    }

    private func drawPectoralFins(_ points: [(point: Point, direction: Double)], on canvas: PixelBuffer) {
        let shoulder = points[3]
        for side in [-1.0, 1.0] {
            canvas.plot(shoulder.point.moved(by: species.halfWidth + 1, heading: shoulder.direction + side * 2.2), species.fin)
        }
    }

    private func drawMarking(at point: Point, across: Double, step: Int, half: Double, on canvas: PixelBuffer) {
        switch species.markingStyle {
        case .none:
            break
        case .shoulderSpot where step == 3:
            for side in [-1.0, 1.0] { canvas.plot(point.moved(by: side * half, heading: across), species.marking) }
        case .crossBars where step == 4 || step == 7 || step == 10:
            for offset in stride(from: -half, through: half, by: 0.5) { canvas.plot(point.moved(by: offset, heading: across), species.marking) }
        case .spineStripe where step >= 3 && step <= species.length - 5:
            canvas.plot(point, species.marking)
        default:
            break
        }
    }
}
