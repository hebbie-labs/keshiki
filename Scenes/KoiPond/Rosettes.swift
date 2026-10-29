import Foundation

/// Rosettes of arrowhead (Sagittaria) on the floor: pointed leaves fanning out from a heart, so they look right
/// from above whichever way you see them. The leaves sway a little and bend aside when a koi swims over.
struct Rosette {
    struct Leaf {
        let heading: Double
        let length: Double
        let width: Double
        let phase: Double
        /// 0 for the young leaves in the middle, 1 for the old ones lying out flat.
        let age: Double
    }

    let root: Point
    let leaves: [Leaf]
    /// How far a passing koi has pushed the tips aside, in design units; it springs back.
    var bend = Point(x: 0, y: 0)

    static let reach = 30.0
}

extension PondWorld {
    private static let rosettes = 18
    private static let leavesPerRosette = 8...12
    /// Old outer leaves are darker and murkier, the young ones in the middle fresh and light.
    private static let oldLeaf = Color(0x2c4f34), youngLeaf = Color(0x7aa458)
    private static let leafRim = Color(0x173022)
    /// Faint discs that overlap into a soft shadow.
    private static let shadow = Color(0x0b2a20, alpha: 0.08)
    /// The sun's slant through the water: how far a shadow lands from what casts it, per unit of height.
    private static let sunSlant = Point(x: -0.1, y: 0.34)
    /// How high a leaf's tip stands off the floor, compared to its length: the young leaves stand up, the old lie flat.
    private static let rise = 0.35

    /// On the floor where it's neither too shallow nor too deep for the light, often a few together.
    static func plantRosettes(in size: SceneSize) -> [Rosette] {
        var rosettes: [Rosette] = []
        while rosettes.count < Self.rosettes {
            let root = rosettes.last.flatMap { chance(0.45) ? $0.root.jittered(26, 20) : nil } ?? size.randomPoint(marginX: 30, marginY: 25)
            let depth = PondFloor.depth(x: root.x, y: root.y, size: size)
            guard depth > 0.08, depth < 0.65 else { continue }
            rosettes.append(rosette(at: root))
        }
        return rosettes
    }

    /// In an overgrown pond, rosettes crowding the edges all round, some grown big. Too many to sway every frame,
    /// so they're painted into the floor once (`paintRosettes`).
    static func plantEdgeRosettes(in size: SceneSize, waterName: String) -> [Rosette] {
        var rosettes: [Rosette] = []
        for _ in 0..<WaterPalette.named(waterName).edgePlants {
            let inward = random(6...80)
            let root = switch Int.random(in: 0..<4) {
            case 0: Point(x: inward, y: random(0...size.height))
            case 1: Point(x: size.width - inward, y: random(0...size.height))
            case 2: Point(x: random(0...size.width), y: inward)
            default: Point(x: random(0...size.width), y: size.height - inward)
            }
            rosettes.append(rosette(at: root, span: chance(0.35) ? random(32...50) : random(16...28)))
        }
        // The big ones first, so the smaller ones grow over them.
        rosettes.sort { $0.leaves[0].length > $1.leaves[0].length }
        return rosettes
    }

    private static func rosette(at root: Point, span: Double = random(16...28)) -> Rosette {
        let count = Int.random(in: Self.leavesPerRosette)
        let leaves = (0..<count).map { index in
            let age = Double(index) / Double(count - 1)
            return Rosette.Leaf(heading: Double(index) * 2.4 + random(-0.25...0.25), length: span * (0.45 + 0.55 * age) * random(0.85...1.1),
                                width: random(2.2...3.2) * (0.7 + 0.3 * age) * max(1, span / 28), phase: random(0...(2 * .pi)), age: age)
        }
        // Old leaves first, so the young ones lie on top.
        return Rosette(root: root, leaves: leaves.reversed())
    }

    func moveRosettes(dt: Double) {
        for index in rosettes.indices {
            var rosette = rosettes[index]
            rosette.bend.x *= 1 - dt * 1.5
            rosette.bend.y *= 1 - dt * 1.5
            for koi in kois {
                let dx = rosette.root.x - koi.head.x, dy = rosette.root.y - koi.head.y, distance = hypot(dx, dy)
                guard distance < Rosette.reach, distance > 0.5 else { continue }
                let push = (1 - distance / Rosette.reach) * 24 * dt
                rosette.bend.x += dx / distance * push
                rosette.bend.y += dy / distance * push
            }
            let bent = hypot(rosette.bend.x, rosette.bend.y)
            if bent > 6 { rosette.bend = Point(x: rosette.bend.x / bent * 6, y: rosette.bend.y / bent * 6) }
            rosettes[index] = rosette
        }
    }

    /// Drawn every frame, in steps coarse enough to stay light; all shadows first, then the leaves.
    func drawRosettes(on canvas: Canvas) {
        Self.draw(rosettes, on: canvas, clock: clock, step: 0.8)
    }

    /// Paints rosettes that never move once, finely, e.g. into the floor.
    static func paintRosettes(_ rosettes: [Rosette], on canvas: Canvas) {
        draw(rosettes, on: canvas, clock: 0, step: 0.4)
    }

    private static func draw(_ rosettes: [Rosette], on canvas: Canvas, clock: Double, step: Double) {
        for shadows in [true, false] {
            for rosette in rosettes {
                for leaf in rosette.leaves { drawLeaf(leaf, of: rosette, asShadow: shadows, on: canvas, clock: clock, step: step) }
            }
        }
    }

    /// A leaf is a pointed oval on a short stalk: a dark rim, then the blade lit on the sun's side, and a pale midrib.
    /// `step` is how far apart its discs lie, in design units.
    private static func drawLeaf(_ leaf: Rosette.Leaf, of rosette: Rosette, asShadow: Bool, on canvas: Canvas, clock: Double, step: Double) {
        let sway = sin(clock * 0.9 + leaf.phase) * 0.06 * leaf.age
        let heading = leaf.heading + sway
        var points: [(spot: Point, width: Double, t: Double)] = []
        for step in stride(from: 0.0, through: leaf.length, by: step) {
            let t = step / leaf.length
            // A short stalk, then the blade: widest past the middle, coming to a point.
            let blade = t < 0.2 ? 0.25 : sin(.pi * pow((t - 0.2) / 0.8, 0.8))
            let spot = rosette.root.moved(by: step, heading: heading)
            points.append((Point(x: spot.x + rosette.bend.x * t, y: spot.y + rosette.bend.y * t), leaf.width * blade, t))
        }
        if asShadow {
            for (index, part) in points.enumerated() where index.isMultiple(of: max(1, Int(1.2 / step))) {
                let height = part.t * leaf.length * Self.rise * (1.2 - leaf.age)
                canvas.disc(Point(x: part.spot.x + Self.sunSlant.x * height, y: part.spot.y + Self.sunSlant.y * height),
                            radius: part.width + 0.8, Self.shadow)
            }
            return
        }
        let sunny = (cos(heading - .pi * 1.25) + 1) / 2
        let color = Self.oldLeaf.mixed(with: Self.youngLeaf, 1 - leaf.age * 0.8).mixed(with: Self.leafRim, 0.25 * (1 - sunny))
        for part in points { canvas.disc(part.spot, radius: part.width + 0.35, Self.leafRim.opacity(0.7)) }
        for part in points { canvas.disc(part.spot, radius: part.width, color.mixed(with: Self.youngLeaf, 0.2 * part.t * sunny)) }
        // The midrib is too fine to see in the coarse drawing done every frame.
        for part in points where step < 0.5 && part.t > 0.15 && part.t < 0.9 {
            canvas.disc(part.spot, radius: 0.22, color.mixed(with: Color(0xd8e8a0), 0.35))
        }
    }
}
