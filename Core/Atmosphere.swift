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

    var tint: Color {
        switch self {
        case .dawn: return Color(0xffaabe, alpha: 0.13)
        case .day: return Color(0xffffe6, alpha: 0.03)
        case .golden: return Color(0xffaa3c, alpha: 0.18)
        case .dusk: return Color(0x5a2878, alpha: 0.30)
        case .night: return Color(0x050a28, alpha: 0.56)
        }
    }

    var hasFireflies: Bool { self == .dusk || self == .night }
}

/// The light over any scene: the time-of-day tint, a grey veil when it rains, and fireflies after dark.
final class Atmosphere {
    private struct Firefly {
        var position: Point
        let drift: Point
        let phase: Double
    }

    private var fireflies: [Firefly] = []

    private static let fireflyCount = 24
    private static let rainDimming = Color(0x283c50, alpha: 0.16)

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
            canvas.disc(fly.position, radius: 3, Color(0xf0ff8c, alpha: glow * 0.18))
            canvas.fillRect(fly.position, width: 2, height: 2, Color(0xfaffaa, alpha: glow))
        }
    }
}
