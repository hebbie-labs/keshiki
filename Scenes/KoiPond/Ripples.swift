import Foundation


struct Ripple {
    var center: Point
    var radius: Double
    var life: Double
}

extension PondWorld {
    private static let rippleGrowthPerSecond = 26.0
    private static let rippleFadePerSecond = 0.8
    private static let raindropsPerFrame = 3

    func addRipple(at center: Point, radius: Double = 1, life: Double = 1) {
        ripples.append(Ripple(center: center, radius: radius, life: life))
    }

    func addRaindrops() {
        for _ in 0..<Self.raindropsPerFrame where chance(0.6) {
            addRipple(at: size.randomPoint(marginX: 0), radius: 0.5, life: 0.6)
        }
    }

    func updateRipples(dt: Double) {
        for index in ripples.indices {
            ripples[index].radius += dt * Self.rippleGrowthPerSecond
            ripples[index].life -= dt * Self.rippleFadePerSecond
        }
        ripples.removeAll { $0.life <= 0 }
    }

    func drawRipples(on canvas: PixelBuffer) {
        for ripple in ripples {
            canvas.ring(ripple.center, radius: ripple.radius, Color(0xdcfff0, alpha: ripple.life * 0.55))
        }
    }
}
