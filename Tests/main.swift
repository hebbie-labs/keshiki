import CoreGraphics
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

let shared = SharedSettings([SharedSettings.generalKey: Data(#"{"theme":"dusk","rain":true}"#.utf8),
                             SharedSettings.koiPondKey: Data(#"{"water":"deep-clear"}"#.utf8)])
check(shared.general.theme == "dusk" && shared.general.rain && shared.koiPond.water == "deep-clear", "the screensaver and the wallpaper read the app's settings")
check(SharedSettings(["settings": Data("garbage".utf8)]).general == KeshikiSettings(), "unreadable shared settings fall back to the defaults")

// Swimming
let pondWorld = PondWorld(size: SceneSize(width: 960, height: 600), options: KoiPondSettings())
for _ in 0..<600 { pondWorld.update(dt: 1.0 / 30) }
let gaps = zip(pondWorld.kois[0].body, pondWorld.kois[0].body.dropFirst()).map { $0.distance(to: $1) }
check(gaps.max()! - gaps.min()! < 0.01, "a koi's body keeps its segment length while it swings")
for _ in 0..<40 {
    pondWorld.touchWater(at: pondWorld.pads[0].center.jittered(20))
    pondWorld.update(dt: 1.0 / 30)
}
let pushed = pondWorld.pads[0].offset
for _ in 0..<900 { pondWorld.update(dt: 1.0 / 30) }
check(hypot(pushed.x, pushed.y) > 1 && pondWorld.pads.allSatisfy { hypot($0.offset.x, $0.offset.y) < 12 }, "waves push the lily pads and their stems pull them back")

// A fresh pond: its frog rests at least ten seconds before its first jump (and splash).
let splashWorld = PondWorld(size: SceneSize(width: 960, height: 600), options: KoiPondSettings())
splashWorld.splash(at: Point(x: 400, y: 300), droplets: 10, power: 50)
let thrown = splashWorld.droplets.count
for _ in 0..<60 { splashWorld.update(dt: 1.0 / 30) }
check(thrown == 10 && splashWorld.droplets.isEmpty, "a splash throws droplets that fall back into the water")
let padCanvas = DrawList(width: 1440, height: 900, scale: 1.5)
for _ in 0..<40 { LilyPad.scatter(in: SceneSize(width: 960, height: 600)).forEach { $0.draw(on: padCanvas) } }
check(padCanvas.primitives.allSatisfy { $0.bounds.x < $0.bounds.z && $0.bounds.y < $0.bounds.w }, "lily pads of any shape draw clean rows, slit and all")

// Ponds across displays: two side by side (y up, like screen frames), one a little apart.
let left = PondWorld(size: SceneSize(width: 960, height: 600), options: KoiPondSettings())
let right = PondWorld(size: SceneSize(width: 960, height: 600), options: KoiPondSettings())
let apart = PondWorld(size: SceneSize(width: 960, height: 600), options: KoiPondSettings())
let links = PondLinks([(left, CGRect(x: 0, y: 0, width: 1000, height: 625)), (right, CGRect(x: 1000, y: 0, width: 1000, height: 625)),
                       (apart, CGRect(x: 0, y: 700, width: 1000, height: 625))], unitsPerPoint: 0.96)
check(left.openings.count == 1 && left.openings[0].edge == .right && abs(left.openings[0].span.upperBound - 600) < 0.01
      && right.openings.first?.edge == .left && apart.openings.isEmpty, "displays that touch open into each other, a gap stays a wall")
let traveller = left.kois[0]
traveller.shift(by: Point(x: 965 - traveller.head.x, y: 300 - traveller.head.y))
links.exchange()
check(left.kois.count == 7 && right.kois.count == 9 && right.kois.contains { $0 === traveller } && near(traveller.head, Point(x: 5, y: 300)),
      "a koi that swims out on one display comes in on the next, at the same height")
check(left.visibility(at: Point(x: 950, y: 300)) < 0.5 && left.visibility(at: Point(x: 10, y: 300)) == 1,
      "fish dive under at an opening, not at a wall")

let reeds = Reeds.make(size: SceneSize(width: 960, height: 600), scale: 1.5)
check(!reeds.sprites.isEmpty && reeds.sprites.allSatisfy { ($0.root.y < 600 * 0.8 || abs($0.root.x - 480) > 160) && $0.x + $0.width <= reeds.sheet.width },
      "reeds stand along the far and side edges and in the near corners, never in front, each cut from the sheet")

// Drawing
let tiny = PixelBuffer(width: 10, height: 10)
tiny.fillRect(Point(x: 3, y: -20), width: 2, height: 2, Color(0xffffff))
tiny.fillRect(Point(x: 40, y: 3), width: 2, height: 2, Color(0xffffff))
tiny.heart(Point(x: 5, y: -30), opacity: 1)
check(tiny.pixels.allSatisfy { $0 == Color(0x000000).packed }, "drawing off the canvas is ignored instead of crashing")

let scaled = PixelBuffer(width: 30, height: 30, scale: 1.5)
scaled.plot(Point(x: 2, y: 2), Color(0xffffff))
let lit = scaled.pixels.indices.filter { scaled.pixels[$0] != Color(0x000000).packed }.map { ($0 % 30, $0 / 30) }
// x = 2 design → 3 ..< round(4.5) = 5 device pixels, the same vertically.
check(lit.map(\.0).min() == 3 && lit.map(\.0).max() == 4 && lit.count == 4, "a design pixel lands on whole device pixels")

/// A scene with one disc on black, to check the GPU draws exactly what the CPU painter would.
final class DiscScene: LivingScene {
    var settings = KeshikiSettings()
    var systemDark = false
    let pixelWidth = 64, pixelHeight = 64, pixelScale = 1.5
    var water: WaterSurface? { nil }
    private var backdrop: PixelBuffer? = PixelBuffer(width: 64, height: 64)
    func advance(by dt: Double) {}
    func takeNewBackdrop() -> PixelBuffer? { defer { backdrop = nil }; return backdrop }
    private var overlay: PixelBuffer? = {
        let layer = PixelBuffer(width: 64, height: 64, scale: 1.5, color: nil)
        layer.fillRect(Point(x: 40, y: 40), width: 6, height: 4, Color(0x2d6a3a))
        return layer
    }()
    func takeNewOverlay() -> PixelBuffer? { defer { overlay = nil }; return overlay }
    func draw(on canvas: Canvas, at date: Date) {
        canvas.disc(Point(x: 20.3, y: 19.6), radius: 9.4, Color(0xe0412f))
        canvas.fillRect(Point(x: 2, y: 2), width: 3, height: 1, Color(0x2f86e8))
        canvas.placeOverlay()
    }
    func touch(at spot: Point, withOption: Bool) {}
}

if SceneRenderer.isAvailable {
    let discScene = DiscScene()
    let gpu = SceneRenderer(scene: discScene)!.snapshot(discScene)
    let cpu = PixelBuffer(width: 64, height: 64, scale: 1.5)
    discScene.draw(on: cpu, at: Date())
    cpu.fillRect(Point(x: 40, y: 40), width: 6, height: 4, Color(0x2d6a3a))
    var gpuPixels = PixelBuffer(width: 64, height: 64).pixels
    if let gpu, let data = gpu.dataProvider?.data as Data? { gpuPixels = data.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) } }
    check(gpuPixels.map { $0 | 0xff00_0000 } == cpu.pixels, "the GPU draws discs, rectangles and the overlay pixel for pixel like the CPU")

    let scene = SceneKind.koiPond.make(aspectRatio: 16.0 / 10.0, settings: KeshikiSettings())
    for _ in 0..<90 { scene.advance(by: 1.0 / 30) }
    let frame = SceneRenderer(scene: scene)!.snapshot(scene)
    check(frame?.width == Int(960 * scene.pixelScale) && frame?.height == Int(600 * scene.pixelScale), "a 16:10 pond renders at its pixel scale (1920×1200 on power)")

    let pond = SceneKind.koiPond.make(aspectRatio: WaterStage.pondAspect(screenAspect: 1.6), settings: KeshikiSettings())
    let stage = WaterStage(scene: pond, screenAspect: 1.6)
    let still = stage?.snapshot(width: 640, height: 400)
    check(still?.width == 640 && still?.height == 400, "the pond renders in 3D at the display's size")
    let middle = stage?.pondSpot(forViewSpot: Point(x: 0.5, y: 0.5)), back = middle.flatMap { stage?.viewSpot(forPondSpot: $0) }
    check(near(back, Point(x: 0.5, y: 0.5)), "a click on the screen finds its spot in the pond and back")
} else {
    print("– no Metal device, GPU checks skipped")
}

exit(failures == 0 ? 0 : 1)
