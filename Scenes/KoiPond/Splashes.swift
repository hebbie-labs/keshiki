import Foundation

/// Droplets thrown up when something hits the water; each falls back and leaves a tiny ring where it lands.
struct Droplet {
    var position: Point
    let velocity: Point
    var lift: Double
    var rise: Double
}

extension PondWorld {
    private static let gravity = 160.0
    private static let droplet = Color(0xf4fbff, alpha: 0.85)

    func splash(at point: Point, droplets count: Int, power: Double) {
        for _ in 0..<count {
            let angle = random(0...(2 * .pi)), speed = random(0.3...1) * power
            droplets.append(Droplet(position: point, velocity: Point(x: cos(angle) * speed, y: sin(angle) * speed),
                                    lift: 0, rise: random(0.5...1) * power * 1.6))
        }
    }

    func moveDroplets(dt: Double) {
        for index in droplets.indices {
            droplets[index].position.x += droplets[index].velocity.x * dt
            droplets[index].position.y += droplets[index].velocity.y * dt
            droplets[index].rise -= Self.gravity * dt
            droplets[index].lift += droplets[index].rise * dt
        }
        for landed in droplets where landed.lift < 0 { water.drop(at: landed.position, radius: 1, strength: 0.06) }
        droplets.removeAll { $0.lift < 0 }
    }

    func drawDroplets(on canvas: Canvas) {
        for drop in droplets { canvas.plot(Point(x: drop.position.x, y: drop.position.y - drop.lift), Self.droplet) }
    }
}
