import Foundation


struct DuckweedLeaf {
    /// Where the leaf drifts back to, loosely: duckweed patches keep together.
    let home: Point
    let color: Color
    var regrowIn: Double = 0
    var offset = Point(x: 0, y: 0)
    var drift = Point(x: 0, y: 0)

    var isEaten: Bool { regrowIn > 0 }
    var position: Point { Point(x: home.x + offset.x, y: home.y + offset.y) }
}

/// Little floating patches the koi graze; eaten leaves grow back.
extension PondWorld {
    private static let patchCount = 4
    private static let leavesPerPatch = 70
    private static let patchRadius = 30.0
    private static let regrowSeconds = 40.0...120.0
    private static let duckweedGreens = [Color(0x8cc152), Color(0xa0d468), Color(0x7cb342)]

    static func scatterDuckweed(in size: SceneSize) -> [DuckweedLeaf] {
        (0..<patchCount).flatMap { _ -> [DuckweedLeaf] in
            let center = size.randomPoint(marginX: 80, marginY: 60)
            return (0..<leavesPerPatch).map { _ in
                let reach = Double.random(in: 0...1).squareRoot() * patchRadius, angle = random(0...6.28)
                let position = Point(x: center.x + cos(angle) * reach * 1.4, y: center.y + sin(angle) * reach)
                return DuckweedLeaf(home: position, color: duckweedGreens.randomElement()!)
            }
        }
    }

    func regrowDuckweed(dt: Double) {
        for index in duckweed.indices where duckweed[index].isEaten { duckweed[index].regrowIn -= dt }
    }

    /// Eats every leaf within reach; true if anything was eaten.
    func grazeDuckweed(near point: Point, reach: Double) -> Bool {
        var grazed = false
        for index in duckweed.indices where !duckweed[index].isEaten && duckweed[index].position.distance(to: point) < reach {
            duckweed[index].regrowIn = random(Self.regrowSeconds)
            grazed = true
        }
        return grazed
    }

    func randomGrowingLeaf() -> Point? {
        duckweed.filter { !$0.isEaten }.randomElement()?.position
    }

    func drawDuckweed(on canvas: Canvas, lotus: Bool = false) {
        // A small round leaf with a lighter speck where it catches the sun. In a lotus pond bigger and brighter,
        // in the style of Nagomi (see THIRD_PARTY_NOTICES.md).
        for (index, leaf) in duckweed.enumerated() where !leaf.isEaten {
            let color = lotus ? Self.lotusDuckweed[index % Self.lotusDuckweed.count] : leaf.color
            let radius = lotus ? 1.2 + Double(index % 5) * 0.35 : 1.1
            canvas.disc(leaf.position, radius: radius, color)
            canvas.disc(Point(x: leaf.position.x - radius * 0.32, y: leaf.position.y - radius * 0.32), radius: radius * 0.32, color.mixed(with: Color(0xffffff), 0.35))
        }
    }

    private static let lotusDuckweed = [Color(0x7ed957), Color(0x5cbf3a), Color(0xa6e86b), Color(0x3f9a2e)]
}
