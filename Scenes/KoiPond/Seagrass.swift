import Foundation

/// Tufts of Vallisneria: long ribbon leaves rising from the floor. They sway in the current and bend aside when a
/// koi swims through.
struct SeagrassTuft {
    struct Blade {
        let root: Point
        let length: Double
        let lean: Double
        let phase: Double
    }

    let root: Point
    let blades: [Blade]
    /// How far a passing koi has pushed the tips aside, in design units; it springs back.
    var bend = Point(x: 0, y: 0)

    static let reach = 34.0
}

extension PondWorld {
    private static let tufts = 13
    private static let bladesPerTuft = 7...11
    private static let seagrass = [Color(0x2e6b34), Color(0x3d8440), Color(0x55a04a), Color(0x7dbe5a)]

    /// Where the floor is neither too shallow nor too deep for the light.
    static func plantSeagrass(in size: SceneSize) -> [SeagrassTuft] {
        var tufts: [SeagrassTuft] = []
        // The leaves stream the way the water flows, fanning out a little.
        let flow = random(0...(2 * .pi))
        while tufts.count < Self.tufts {
            let root = size.randomPoint(marginX: 40, marginY: 30)
            let depth = PondFloor.depth(x: root.x, y: root.y, size: size)
            guard depth > 0.15, depth < 0.7 else { continue }
            let blades = (0..<Int.random(in: Self.bladesPerTuft)).map { _ in
                SeagrassTuft.Blade(root: root.jittered(5, 4), length: random(30...60), lean: flow + random(-0.8...0.8), phase: random(0...(2 * .pi)))
            }
            tufts.append(SeagrassTuft(root: root, blades: blades))
        }
        return tufts
    }

    func moveSeagrass(dt: Double) {
        for index in seagrass.indices {
            var tuft = seagrass[index]
            tuft.bend.x *= 1 - dt * 1.5
            tuft.bend.y *= 1 - dt * 1.5
            for koi in kois {
                let dx = tuft.root.x - koi.head.x, dy = tuft.root.y - koi.head.y, distance = hypot(dx, dy)
                guard distance < SeagrassTuft.reach, distance > 0.5 else { continue }
                let push = (1 - distance / SeagrassTuft.reach) * 40 * dt
                tuft.bend.x += dx / distance * push
                tuft.bend.y += dy / distance * push
            }
            let bent = hypot(tuft.bend.x, tuft.bend.y)
            if bent > 18 { tuft.bend = Point(x: tuft.bend.x / bent * 18, y: tuft.bend.y / bent * 18) }
            seagrass[index] = tuft
        }
    }

    /// Each blade curls with the current (sideways, stronger towards the tip) and leans away from the koi.
    func drawSeagrass(on canvas: Canvas) {
        let current = clock * 0.9
        for tuft in seagrass {
            for blade in tuft.blades {
                var point = blade.root
                // Steps of two design pixels with 2×2 squares: a solid ribbon, half the shapes of single steps.
                let steps = Int(blade.length / 2)
                for step in 0..<steps {
                    let t = Double(step) / Double(steps)
                    let heading = blade.lean + sin(current + blade.phase + t * 2.5) * 0.5 * t
                    point = point.moved(by: 2, heading: heading)
                    let tip = Point(x: point.x + tuft.bend.x * t * t, y: point.y + tuft.bend.y * t * t)
                    canvas.fillRect(tip, width: 2, height: 2, Self.seagrass[min(Self.seagrass.count - 1, Int(t * Double(Self.seagrass.count)))])
                }
            }
        }
    }
}
