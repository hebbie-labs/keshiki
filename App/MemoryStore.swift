import Foundation

/// Keeps what the koi learned (feeding routine, last greeting) across launches.
final class MemoryStore {
    private static let defaultsKey = "pondMemory"
    private var memory: PondMemory

    init() {
        let data = UserDefaults.standard.data(forKey: Self.defaultsKey)
        memory = data.flatMap { try? JSONDecoder().decode(PondMemory.self, from: $0) } ?? PondMemory()
    }

    var lastFeedingSpot: Point? { memory.lastFeedingSpot }

    func usualSpot(at date: Date) -> Point? {
        memory.usualSpot(at: date)
    }

    func recordFeeding(at spot: Point, on date: Date) {
        memory.recordFeeding(at: spot, on: date)
        save()
    }

    func claimDailyGreeting(on date: Date) -> Bool {
        guard memory.claimDailyGreeting(on: date) else { return false }
        save()
        return true
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(memory), forKey: Self.defaultsKey)
    }
}
