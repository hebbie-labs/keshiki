import Foundation

extension PondWorld {
    private static let raindropsPerFrame = 3

    /// Disturbs the water; the waves spread, overlap and bounce off the edges and the lily pads.
    func addRipple(at center: Point, radius: Double = 3, strength: Double = 1) {
        water.drop(at: center, radius: radius, strength: strength)
        pushFloating(from: center, strength: strength, reach: 50 + radius * 3)
    }

    func addRaindrops() {
        for _ in 0..<Self.raindropsPerFrame where chance(0.6) {
            let spot = size.randomPoint(marginX: 0)
            addRipple(at: spot, radius: 1.5, strength: 0.35)
            if chance(0.4) { splash(at: spot, droplets: 1, power: 22) }
        }
    }
}
