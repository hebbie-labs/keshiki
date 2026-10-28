import Foundation

/// What the koi remember: where and when you feed them, and when they last said good morning.
struct PondMemory: Codable {
    struct Feeding: Codable {
        /// Normalised (0...1) so it survives different screen sizes.
        let x: Double
        let y: Double
        let minute: Int
        let day: String
    }

    private(set) var feedings: [Feeding] = []
    private(set) var lastGreetingDay = ""

    private static let minutesPerDay = 24 * 60
    private static let routineWindowMinutes = 20
    private static let daysToLearnRoutine = 2
    private static let feedingsRemembered = 60

    mutating func recordFeeding(at spot: Point, on date: Date) {
        feedings.append(Feeding(x: spot.x, y: spot.y, minute: Self.minuteOfDay(date), day: Self.dayKey(date)))
        feedings = Array(feedings.suffix(Self.feedingsRemembered))
    }

    /// Where you usually feed them around this time of day, once seen on at least two different days.
    func usualSpot(at date: Date) -> Point? {
        let now = Self.minuteOfDay(date)
        let nearby = feedings.filter { Self.minutesApart($0.minute, now) <= Self.routineWindowMinutes }
        guard Set(nearby.map(\.day)).count >= Self.daysToLearnRoutine else { return nil }
        let count = Double(nearby.count)
        return Point(x: nearby.map(\.x).reduce(0, +) / count, y: nearby.map(\.y).reduce(0, +) / count)
    }

    var lastFeedingSpot: Point? {
        feedings.last.map { Point(x: $0.x, y: $0.y) }
    }

    /// True only for the first call on each calendar day.
    mutating func claimDailyGreeting(on date: Date) -> Bool {
        let day = Self.dayKey(date)
        guard lastGreetingDay != day else { return false }
        lastGreetingDay = day
        return true
    }

    static func minuteOfDay(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private static func dayKey(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private static func minutesApart(_ a: Int, _ b: Int) -> Int {
        let difference = abs(a - b) % minutesPerDay
        return min(difference, minutesPerDay - difference)
    }
}
