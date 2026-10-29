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
    private static let bladesPerTuft = 4...6
    /// A leaf from its root deep down, murky with water, to the tip up in the light: its middle and its lighter edge.
    private static let leafMiddle = [Color(0x24503a), Color(0x2f6640), Color(0x3c7c44), Color(0x4f924a), Color(0x68a852)]
    private static let leafEdge = [Color(0x3a6a48), Color(0x4a8450), Color(0x5e9c56), Color(0x78b460), Color(0x96cc6e)]
    /// What a leaf darkens towards where it twists its narrow side up.
    private static let twisted = Color(0x10281c)
    /// Faint discs that overlap into a soft shadow.
    private static let shadow = Color(0x0b2e26, alpha: 0.07)
    /// The sun's slant through the water: how far a shadow lands from what casts it, per unit of height.
    private static let sunSlant = Point(x: -0.1, y: 0.34)
    /// How high up a blade's tip reaches, compared to its length: seen from above, the leaves mostly stream along
    /// in the current rather than stand up.
    private static let rise = 0.3
    /// Half the width of a leaf at its root; it narrows towards a rounded tip.
    private static let halfWidth = 2.2

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
                SeagrassTuft.Blade(root: root.jittered(4, 3), length: random(40...75), lean: flow + random(-0.6...0.6), phase: random(0...(2 * .pi)))
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

    /// Each leaf is a flat ribbon that sways as a whole in the current, more towards the tip, and leans away from the
    /// koi. Where it twists it turns its narrow side up and darkens. Its soft shadow drifts off it the higher it reaches.
    func drawSeagrass(on canvas: Canvas) {
        for shadows in [true, false] {
            for tuft in seagrass {
                for blade in tuft.blades { drawBlade(blade, of: tuft, asShadow: shadows, on: canvas) }
            }
        }
    }

    private func drawBlade(_ blade: SeagrassTuft.Blade, of tuft: SeagrassTuft, asShadow: Bool, on canvas: Canvas) {
        let current = clock * 0.8 + blade.phase
        var point = blade.root
        var leaf: [(spot: Point, t: Double, width: Double, twist: Double)] = []
        let steps = Int(blade.length)
        for step in 0..<steps {
            let t = Double(step) / Double(steps)
            let heading = blade.lean + sin(current - t * 1.6) * 0.45 * t + sin(current * 0.53 + 1) * 0.15
            point = point.moved(by: 1, heading: heading)
            let twist = 0.55 + 0.45 * abs(cos(current * 0.7 + t * 3))
            let taper = t < 0.85 ? 1 - t * 0.45 : (1 - 0.85 * 0.45) * ((1 - t) / 0.15).squareRoot()
            leaf.append((Point(x: point.x + tuft.bend.x * t * t, y: point.y + tuft.bend.y * t * t), t, Self.halfWidth * taper * twist, twist))
        }
        if asShadow {
            for (index, part) in leaf.enumerated() where index.isMultiple(of: 2) {
                let height = part.t * blade.length * Self.rise
                canvas.disc(Point(x: part.spot.x + Self.sunSlant.x * height, y: part.spot.y + Self.sunSlant.y * height),
                            radius: part.width + 1.5 + part.t * 1.5, Self.shadow)
            }
            return
        }
        // The whole edge first, then the whole middle over it, so the ribbon is smooth rather than scaled.
        for (colors, share) in [(Self.leafEdge, 1.0), (Self.leafMiddle, 0.55)] {
            for part in leaf {
                // Blended between the two nearest colours, so the leaf shades smoothly from root to tip.
                let along = part.t * Double(colors.count - 1), lower = Int(along)
                let shade = colors[lower].mixed(with: colors[min(colors.count - 1, lower + 1)], along - Double(lower))
                canvas.disc(part.spot, radius: part.width * share, shade.mixed(with: Self.twisted, (1 - part.twist) * 0.8))
            }
        }
    }
}
