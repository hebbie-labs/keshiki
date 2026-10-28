import Foundation

/// Lives on the lily pads and hops to another one now and then.
final class Frog {
    private struct Jump {
        let from: Int
        let to: Int
        var progress = 0.0
    }

    /// The pad it sits on, in `PondWorld.pads`.
    private(set) var padIndex = 0
    private var jump: Jump?
    private var restingFor = random(10...30)
    private var blinkIn = 0.0

    private static let jumpSeconds = 0.8
    private static let jumpHeight = 24.0
    private static let maxJumpDistance = 300.0
    private static let restSeconds = 15.0...45.0
    private static let green = Color(0x5fa83a)


    func update(in world: PondWorld, dt: Double) {
        restingFor -= dt
        blinkIn -= dt
        if blinkIn < -0.15 { blinkIn = random(2...6) }
        if jump == nil && restingFor <= 0 { startJump(in: world) }
        if var current = jump {
            current.progress += dt / Self.jumpSeconds
            jump = current
            if current.progress >= 1 { land(in: world) }
        }
    }

    func draw(on canvas: Canvas, time: Double, pads: [LilyPad]) {
        let (position, lift) = positionAndLift(on: pads)
        canvas.disc(Point(x: position.x + 3 + lift * 0.3, y: position.y + 4 + lift * 0.4), radius: 6, Color(0x0b2e26, alpha: 0.3))
        let top = Point(x: position.x, y: position.y - lift)
        for side in [-1.0, 1.0] { canvas.disc(Point(x: top.x + side * 5, y: top.y + 4), radius: 2.5, Color(0x3f7d2c)) }
        canvas.disc(top, radius: 6, Self.green)
        canvas.disc(Point(x: top.x, y: top.y + 1), radius: 4, Color(0x78bf4c))
        for side in [-1.0, 1.0] {
            let eye = Point(x: top.x + side * 3.5, y: top.y - 4.5)
            canvas.disc(eye, radius: 2.2, Self.green)
            canvas.plot(Point(x: eye.x, y: eye.y - 0.5), blinkIn < 0 ? Self.green : Color(0x141414))
        }
    }

    private func startJump(in world: PondWorld) {
        let pad = world.pads[padIndex]
        let nearby = world.pads.indices.filter { $0 != padIndex && world.pads[$0].center.distance(to: pad.center) < Self.maxJumpDistance }
        guard let target = nearby.randomElement() ?? world.pads.indices.randomElement() else { return }
        jump = Jump(from: padIndex, to: target)
        restingFor = random(Self.restSeconds)
        world.addRipple(at: pad.position, radius: pad.radius, strength: 0.7)
    }

    private func land(in world: PondWorld) {
        guard let landing = jump?.to else { return }
        padIndex = landing
        jump = nil
        let pad = world.pads[padIndex]
        world.addRipple(at: pad.position, radius: pad.radius, strength: 0.8)
    }

    private func positionAndLift(on pads: [LilyPad]) -> (Point, Double) {
        guard let jump else {
            let pad = pads[padIndex].position
            return (Point(x: pad.x - 2, y: pad.y), 0)
        }
        let t = jump.progress, from = pads[jump.from].position, to = pads[jump.to].position
        return (Point(x: from.x + (to.x - from.x) * t, y: from.y + (to.y - from.y) * t), sin(t * .pi) * Self.jumpHeight)
    }
}
