import Foundation


struct DuckweedLeaf {
    let position: Point
    let color: Color
    var regrowIn: Double = 0

    var isEaten: Bool { regrowIn > 0 }
}

/// Little floating patches the koi graze; eaten leaves grow back.
extension World {
    private static let patchCount = 4
    private static let leavesPerPatch = 70
    private static let patchRadius = 30.0
    private static let regrowSeconds = 40.0...120.0
    private static let duckweedGreens = [Color(0x8cc152), Color(0xa0d468), Color(0x7cb342)]

    static func scatterDuckweed(in size: PondSize) -> [DuckweedLeaf] {
        (0..<patchCount).flatMap { _ -> [DuckweedLeaf] in
            let center = size.randomPoint(marginX: 80, marginY: 60)
            return (0..<leavesPerPatch).map { _ in
                let reach = Double.random(in: 0...1).squareRoot() * patchRadius, angle = random(0...6.28)
                let position = Point(x: center.x + cos(angle) * reach * 1.4, y: center.y + sin(angle) * reach)
                return DuckweedLeaf(position: position, color: duckweedGreens.randomElement()!)
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

    func drawDuckweed(on canvas: PixelBuffer) {
        for leaf in duckweed where !leaf.isEaten { canvas.fillRect(leaf.position, width: 2, height: 2, leaf.color) }
    }
}
