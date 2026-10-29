import Foundation

/// What floats gets pushed around by the waves and by the fish swimming underneath. Lily pads are held by their
/// stems and spring back; duckweed drifts loosely around its patch; the ball rolls off.
extension PondWorld {
    /// Spring and damping per second²/second; the pads are held firmly, the duckweed barely.
    private static let padHold = 0.8, padDamping = 1.6
    private static let leafHold = 0.08, leafDamping = 0.9
    /// How hard a drop of strength 1 pushes something right next to it, in design units per second.
    private static let wavePush = 14.0
    private static let koiPush = 0.6
    /// A light, slowly turning breeze, in design units per second².
    private static let breeze = 0.25

    /// The waves of a drop push floating things away from it, less the farther off they are.
    // ponytail: the push stands in for reading the GPU waves back; the pads' obstacles in the water stay at their stems.
    func pushFloating(from center: Point, strength: Double, reach: Double) {
        func impulse(at point: Point) -> Point? {
            let dx = point.x - center.x, dy = point.y - center.y, distance = hypot(dx, dy)
            guard distance < reach, distance > 0.5 else { return nil }
            let push = strength * Self.wavePush * (1 - distance / reach)
            return Point(x: dx / distance * push, y: dy / distance * push)
        }
        for index in pads.indices {
            guard let push = impulse(at: pads[index].position) else { continue }
            let mass = pads[index].radius / 30
            pads[index].drift.x += push.x / mass
            pads[index].drift.y += push.y / mass
            pads[index].spin += (push.x - push.y) * 0.004 / mass
        }
        for index in duckweed.indices {
            guard let push = impulse(at: duckweed[index].position) else { continue }
            duckweed[index].drift.x += push.x
            duckweed[index].drift.y += push.y
        }
        if let ball, let push = impulse(at: ball.position) { ball.push(Point(x: push.x / 60, y: push.y / 60)) }
    }

    func moveFloating(dt: Double) {
        let wind = Point(x: sin(clock * 0.05) * Self.breeze, y: cos(clock * 0.037) * Self.breeze)
        for index in pads.indices {
            var pad = pads[index]
            for koi in kois where koi.head.distance(to: pad.position) < pad.radius {
                pad.drift.x += cos(koi.heading) * koi.velocity * Self.koiPush / (pad.radius / 30)
                pad.drift.y += sin(koi.heading) * koi.velocity * Self.koiPush / (pad.radius / 30)
            }
            pad.drift.x += (wind.x - pad.offset.x * Self.padHold - pad.drift.x * Self.padDamping) * dt
            pad.drift.y += (wind.y - pad.offset.y * Self.padHold - pad.drift.y * Self.padDamping) * dt
            pad.offset.x += pad.drift.x * dt
            pad.offset.y += pad.drift.y * dt
            pad.spin += (-pad.turn * Self.padHold - pad.spin * Self.padDamping) * dt
            pad.turn += pad.spin * dt
            pads[index] = pad
        }
        for index in duckweed.indices {
            var leaf = duckweed[index]
            for koi in kois where koi.head.distance(to: leaf.position) < 8 {
                leaf.drift.x += cos(koi.heading) * koi.velocity * Self.koiPush * 2
                leaf.drift.y += sin(koi.heading) * koi.velocity * Self.koiPush * 2
            }
            leaf.drift.x += (wind.x - leaf.offset.x * Self.leafHold - leaf.drift.x * Self.leafDamping) * dt
            leaf.drift.y += (wind.y - leaf.offset.y * Self.leafHold - leaf.drift.y * Self.leafDamping) * dt
            leaf.offset.x += leaf.drift.x * dt
            leaf.offset.y += leaf.drift.y * dt
            duckweed[index] = leaf
        }
    }
}
