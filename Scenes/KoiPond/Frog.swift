import Foundation

/// Lives on the lily pads and hops to another one now and then.
final class Frog {
    private struct Jump {
        let from: LilyPad
        let to: LilyPad
        var progress = 0.0
    }

    private(set) var pad: LilyPad
    private var jump: Jump?
    private var restingFor = random(10...30)
    private var blinkIn = 0.0

    private static let jumpSeconds = 0.8
    private static let jumpHeight = 24.0
    private static let maxJumpDistance = 300.0
    private static let restSeconds = 15.0...45.0
    private static let green = Color(0x5fa83a)

    init(pad: LilyPad) {
        self.pad = pad
    }

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

    func draw(on canvas: PixelBuffer, time: Double) {
        let (position, lift) = positionAndLift(at: time)
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
        let nearby = world.pads.filter { $0.center != pad.center && $0.center.distance(to: pad.center) < Self.maxJumpDistance }
        guard let target = nearby.randomElement() ?? world.pads.randomElement() else { return }
        jump = Jump(from: pad, to: target)
        restingFor = random(Self.restSeconds)
        world.addRipple(at: pad.center, radius: 4, life: 0.7)
    }

    private func land(in world: PondWorld) {
        guard let landing = jump?.to else { return }
        pad = landing
        jump = nil
        world.addRipple(at: pad.center, radius: pad.radius * 0.6, life: 0.8)
    }

    private func positionAndLift(at time: Double) -> (Point, Double) {
        guard let jump else {
            let surface = pad.surface(at: time)
            return (Point(x: surface.x - 2, y: surface.y), 0)
        }
        let t = jump.progress
        let position = Point(x: jump.from.center.x + (jump.to.center.x - jump.from.center.x) * t,
                             y: jump.from.center.y + (jump.to.center.y - jump.from.center.y) * t)
        return (position, sin(t * .pi) * Self.jumpHeight)
    }
}
