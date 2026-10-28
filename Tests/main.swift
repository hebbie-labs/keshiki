import Foundation

// Runnable checks for the logic that's easy to get subtly wrong: `make test`.

var failures = 0

func check(_ condition: Bool, _ description: String) {
    print(condition ? "✔ \(description)" : "✘ \(description)")
    if !condition { failures += 1 }
}

func at(day: Int, _ hour: Int, _ minute: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

func near(_ a: Point?, _ b: Point) -> Bool {
    guard let a else { return false }
    return abs(a.x - b.x) < 0.001 && abs(a.y - b.y) < 0.001
}

// Learning a routine
var memory = KoiMemory()
memory.recordFeeding(at: Point(x: 0.2, y: 0.4), on: at(day: 1, 8, 30))
memory.recordFeeding(at: Point(x: 0.2, y: 0.4), on: at(day: 1, 8, 35))
check(memory.usualSpot(at: at(day: 2, 8, 30)) == nil, "a routine needs feedings on two different days")
memory.recordFeeding(at: Point(x: 0.4, y: 0.6), on: at(day: 2, 8, 25))
check(near(memory.usualSpot(at: at(day: 3, 8, 40)), Point(x: 0.2667, y: 0.4667)), "the usual spot averages nearby feedings")
check(memory.usualSpot(at: at(day: 3, 12, 0)) == nil, "feedings at other times of day are ignored")

var midnight = KoiMemory()
midnight.recordFeeding(at: Point(x: 0.5, y: 0.5), on: at(day: 1, 23, 55))
midnight.recordFeeding(at: Point(x: 0.5, y: 0.5), on: at(day: 2, 23, 50))
check(near(midnight.usualSpot(at: at(day: 3, 0, 5)), Point(x: 0.5, y: 0.5)), "routines wrap around midnight")

var busy = KoiMemory()
for _ in 0..<100 { busy.recordFeeding(at: Point(x: 0, y: 0), on: at(day: 1, 8, 0)) }
check(busy.feedings.count == 60, "only the most recent feedings are remembered")

var greeting = KoiMemory()
check(greeting.claimDailyGreeting(on: at(day: 1, 9, 0)), "the first visit of a day gets a greeting")
check(!greeting.claimDailyGreeting(on: at(day: 1, 18, 0)), "later visits that day don't")
check(greeting.claimDailyGreeting(on: at(day: 2, 7, 0)), "the next day greets again")

// Time of day
check(TimeOfDay.current(theme: "time", systemDark: false, date: at(day: 1, 6, 0)) == .dawn, "6:00 is dawn")
check(TimeOfDay.current(theme: "time", systemDark: false, date: at(day: 1, 12, 0)) == .day, "12:00 is day")
check(TimeOfDay.current(theme: "time", systemDark: false, date: at(day: 1, 18, 0)) == .golden, "18:00 is golden hour")
check(TimeOfDay.current(theme: "time", systemDark: false, date: at(day: 1, 20, 0)) == .dusk, "20:00 is dusk")
check(TimeOfDay.current(theme: "time", systemDark: false, date: at(day: 1, 20, 30)) == .night, "20:30 is night")
check(TimeOfDay.current(theme: "system", systemDark: true, date: at(day: 1, 12, 0)) == .night, "dark mode means night")
check(TimeOfDay.current(theme: "golden", systemDark: false, date: at(day: 1, 3, 0)) == .golden, "a fixed theme ignores the clock")

// Geometry and settings
check(abs(angleDifference(from: 3, to: -3) - (2 * .pi - 6)) < 0.0001, "turning takes the short way round")
let wallpapers = Data(#"{"theme":"night","rain":true,"mood":"playful","lockScreenPond":false}"#.utf8)
let general = try! JSONDecoder().decode(KeshikiSettings.self, from: wallpapers)
check(general.theme == "night" && general.rain && !general.showOnLockScreen && general.scene == .koiPond, "Wallpapers 1.x settings carry over")
check(try! JSONDecoder().decode(KoiPondSettings.self, from: wallpapers).mood == "playful", "the koi fields carry over from the same data")

// Rendering
let tiny = PixelBuffer(width: 10, height: 10)
tiny.fillRect(Point(x: 3, y: -20), width: 2, height: 2, Color(0xffffff))
tiny.fillRect(Point(x: 40, y: 3), width: 2, height: 2, Color(0xffffff))
tiny.heart(Point(x: 5, y: -30), opacity: 1)
check(tiny.pixels.allSatisfy { $0 == Color(0x000000).packed }, "drawing off the canvas is ignored instead of crashing")
let scene = SceneKind.koiPond.make(aspectRatio: 16.0 / 10.0, settings: KeshikiSettings())
for _ in 0..<90 { scene.advance(by: 1.0 / 30) }
let frame = scene.render()
check(frame?.width == 960 && frame?.height == 600, "a 16:10 pond renders at 960×600")

exit(failures == 0 ? 0 : 1)
