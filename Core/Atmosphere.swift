import Foundation

enum TimeOfDay: String {
    case dawn, day, golden, dusk, night

    /// Five times of day that follow the clock, the system appearance, or a fixed choice.
    static func current(theme: String, systemDark: Bool, date: Date) -> TimeOfDay {
        if theme == "system" { return systemDark ? .night : .day }
        if let fixed = TimeOfDay(rawValue: theme) { return fixed }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
        switch hour {
        case 5..<7: return .dawn
        case 7..<17: return .day
        case 17..<19: return .golden
        case 19..<20.5: return .dusk
        default: return .night
        }
    }

    /// A light veil over everything, fish and lily pads included; the water itself carries most of the mood.
    var tint: Color {
        switch self {
        case .dawn: return Color(0xffd2c8, alpha: 0.05)
        case .day: return Color(0xffffe6, alpha: 0.02)
        case .golden: return Color(0xffc864, alpha: 0.10)
        case .dusk: return Color(0x4a3c78, alpha: 0.16)
        case .night: return Color(0x050a28, alpha: 0.38)
        }
    }

    /// The colour of the water body.
    var water: Color {
        switch self {
        case .dawn: return Color(0x86c298)
        case .day: return Color(0x379c70)
        case .golden: return Color(0x8aae58)
        case .dusk: return Color(0x6c6c94)
        case .night: return Color(0x1e2c4c)
        }
    }

    /// The glow over the far side of the pond, where the light comes from.
    var glow: Color {
        switch self {
        case .dawn: return Color(0xfff0dc, alpha: 0.18)
        case .day: return Color(0xc8ffe6, alpha: 0.22)
        case .golden: return Color(0xfff5aa, alpha: 0.30)
        case .dusk: return Color(0xc8c3e6, alpha: 0.15)
        case .night: return Color(0x506e9b, alpha: 0.15)
        }
    }

    /// How strong the sunlight is under water: the caustics and how bright the floor and the fish are.
    var sunlight: Double {
        switch self {
        case .dawn: return 0.8
        case .day: return 1
        case .golden: return 0.9
        case .dusk: return 0.6
        case .night: return 0.3
        }
    }

    var hasFireflies: Bool { self == .dusk || self == .night }
}

/// The light over any scene: the time-of-day tint, a grey veil when it rains, and fireflies after dark, which
/// show again, fainter, mirrored in the water.
final class Atmosphere {
    private struct Firefly {
        var position: Point
        let drift: Point
        let phase: Double
    }

    private var fireflies: [Firefly] = []

    private static let fireflyCount = 14
    private static let rainDimming = Color(0x283c50, alpha: 0.16)
    /// Fireflies hover a little above the water; their mirror image shows this far below them on screen.
    private static let reflectionOffset = 9.0

    func draw(on canvas: Canvas, size: SceneSize, timeOfDay: TimeOfDay, raining: Bool, time: Double) {
        canvas.cover(with: timeOfDay.tint)
        if raining { canvas.cover(with: Self.rainDimming) }
        if timeOfDay.hasFireflies { drawFireflies(on: canvas, size: size, time: time) } else { fireflies.removeAll() }
    }

    private func drawFireflies(on canvas: Canvas, size: SceneSize, time: Double) {
        while fireflies.count < Self.fireflyCount {
            fireflies.append(Firefly(position: size.randomPoint(marginX: 0), drift: Point(x: random(-0.3...0.3), y: random(-0.3...0.3)), phase: random(0...6.28)))
        }
        for index in fireflies.indices {
            var fly = fireflies[index]
            fly.position.x = (fly.position.x + fly.drift.x + size.width).truncatingRemainder(dividingBy: size.width)
            fly.position.y = (fly.position.y + fly.drift.y + sin(time + fly.phase) * 0.15 + size.height).truncatingRemainder(dividingBy: size.height)
            fireflies[index] = fly
            let glow = (sin(time * 2 + fly.phase) + 1) / 2
            let mirrored = Point(x: fly.position.x, y: fly.position.y + Self.reflectionOffset)
            canvas.disc(mirrored, radius: 4, Color(0xf0ff8c, alpha: glow * 0.08))
            canvas.plot(mirrored, Color(0xfaffaa, alpha: glow * 0.45))
            canvas.disc(fly.position, radius: 7, Color(0xf0ff8c, alpha: glow * 0.18))
            canvas.disc(fly.position, radius: 4.5, Color(0xf5ffa0, alpha: glow * 0.4))
            canvas.disc(fly.position, radius: 3, Color(0xfcffd2, alpha: glow))
        }
    }
}
