import Foundation

/// A temari ball floating on the water that the koi (and the goose) push around.
final class Ball {
    private(set) var position: Point
    private var velocity = Point(x: 0, y: 0)
    private var spin = 0.0

    private static let radius = 8.0
    private static let nudgeReach = 14.0
    private static let friction = 0.985
    private static let bounce = 0.8
    private static let threads = [Color(0xd9443a), Color(0x3a6fd9), Color(0xe8b730)]

    init(at position: Point) {
        self.position = position
    }

    /// Pushes the ball along the koi's heading; true if the koi touched it.
    func nudge(by koi: Koi) -> Bool {
        guard position.distance(to: koi.head) < Self.nudgeReach else { return false }
        velocity.x += cos(koi.heading) * koi.velocity * 1.2
        velocity.y += sin(koi.heading) * koi.velocity * 1.2
        return true
    }

    func update(in world: PondWorld, dt: Double) {
        position.x += velocity.x * dt * 60
        position.y += velocity.y * dt * 60
        bounceOffEdges(of: world.size)
        if let goose = world.goose, goose.position.distance(to: position) < 18 {
            velocity.x += (position.x - goose.position.x) * 0.02
            velocity.y += (position.y - goose.position.y) * 0.02
        }
        velocity.x *= Self.friction
        velocity.y *= Self.friction
        spin += hypot(velocity.x, velocity.y) * dt * 0.4
    }

    func draw(on canvas: PixelBuffer) {
        canvas.disc(Point(x: position.x + 4, y: position.y + 5), radius: Self.radius, Color(0x0b2e26, alpha: 0.3))
        canvas.disc(position, radius: Self.radius, Color(0xf3ede0))
        for thread in 0..<6 {
            let angle = spin + Double(thread) / 6 * 2 * .pi
            for reach in 1..<Int(Self.radius) {
                canvas.plot(position.moved(by: Double(reach), heading: angle + Double(reach) * 0.12), Self.threads[thread % 3])
            }
        }
        canvas.disc(position, radius: 2, Self.threads[0])
        canvas.fillRect(Point(x: position.x - 4, y: position.y - 5), width: 2, height: 1, Color(0xffffff, alpha: 0.6))
    }

    private func bounceOffEdges(of size: SceneSize) {
        if position.x < 10 || position.x > size.width - 10 {
            velocity.x *= -Self.bounce
            position.x = clamp(position.x, 10, size.width - 10)
        }
        if position.y < 10 || position.y > size.height - 10 {
            velocity.y *= -Self.bounce
            position.y = clamp(position.y, 10, size.height - 10)
        }
    }
}
