import Foundation

/// Sweet flag (Kalmus) and common reed (Schilf) in clumps along the far and side edges, standing up out of the
/// shallow water. Painted once onto a sheet; the stage stands them up and sways them.
enum Reeds {
    /// One sprite's cell, in design units; the root sits at its bottom middle.
    private static let cellWidth = 30.0, cellHeight = 76.0
    private static let variants = 8

    static func make(size: SceneSize, scale: Double) -> Standing {
        let width = Int((cellWidth * scale).rounded()), height = Int((cellHeight * scale).rounded())
        let sheet = PixelBuffer(width: width * variants, height: height, scale: scale, color: nil)
        for variant in 0..<variants {
            let root = Point(x: (Double(variant) + 0.5) * cellWidth, y: cellHeight - 1)
            if variant.isMultiple(of: 2) { paintSweetFlag(on: sheet, at: root) } else { paintReed(on: sheet, at: root) }
        }
        let sprites = roots(in: size).map { root, sweetFlag in
            Standing.Sprite(root: root, x: width * (Int.random(in: 0..<variants / 2) * 2 + (sweetFlag ? 0 : 1)), y: 0,
                            width: width, height: height, phase: random(0...(2 * .pi)))
        }
        return Standing(sheet: sheet, sprites: sprites)
    }

    /// Clumps along the far edge and down the sides, with gaps; each clump is one kind of plant. They stand a little
    /// in from the rim, which the tilted camera puts at (or just past) the screen's edge, and the near edge stays
    /// open, so they never stand in front of the pond.
    private static func roots(in size: SceneSize) -> [(Point, Bool)] {
        let seed = random(0...100)
        func clump(_ along: Double) -> Bool? {
            guard sin(along * 0.018 + seed) + 0.5 * sin(along * 0.051 + seed * 2) > 0.1 else { return nil }
            return sin(along * 0.009 + seed * 3) > 0
        }
        var roots: [(Point, Bool)] = []
        var along = 0.0
        while along < size.width {
            if let kind = clump(along) { roots.append((Point(x: along, y: random(40...58)), kind)) }
            along += random(7...16)
        }
        for side in [0.0, 1.0] {
            along = 30
            while along < size.height * 0.8 {
                let inset = 16 + 40 * along / size.height + random(0...8)
                if let kind = clump(along + side * 500) { roots.append((Point(x: side == 0 ? inset : size.width - inset, y: along), kind)) }
                along += random(7...16)
            }
        }
        return roots
    }

    /// Sword-shaped leaves fanning from the root, a light midrib, and now and then a flower spike off to the side.
    private static func paintSweetFlag(on sheet: PixelBuffer, at root: Point) {
        let edge = Color(0x2f6b2a), leaf = Color(0x4f9a38), light = Color(0x8cc455), spike = Color(0x9a8a3a)
        for _ in 0..<Int.random(in: 6...9) {
            let lean = random(-0.4...0.4), curve = random(-0.35...0.35), length = random(40...72)
            for along in stride(from: 0.0, to: length, by: 0.7) {
                let progress = along / length, angle = lean + curve * progress * progress
                let point = Point(x: root.x + sin(angle) * along, y: root.y - cos(angle) * along)
                sheet.disc(point, radius: 1.3 * (1 - progress * 0.7), progress < 0.15 ? edge : leaf)
                if progress > 0.2 && progress < 0.9 { sheet.plot(point, light) }
            }
            guard chance(0.3) else { continue }
            let base = Point(x: root.x + sin(lean) * length * 0.55, y: root.y - cos(lean) * length * 0.55)
            for step in 0..<6 { sheet.disc(base.moved(by: Double(step), heading: -.pi / 2 + lean + 0.6), radius: 1.1, spike) }
        }
    }

    /// Thin stems with narrow leaves held out to the sides and a soft, drooping plume on top.
    private static func paintReed(on sheet: PixelBuffer, at root: Point) {
        let stem = Color(0x8f9a58), stemTop = Color(0xb8b070), leaf = Color(0x6f9a48)
        let plume = [Color(0x6e5048), Color(0x8a6a5a), Color(0xa88870)]
        for _ in 0..<Int.random(in: 3...5) {
            let lean = random(-0.15...0.15), length = random(55...73), side = chance(0.5) ? 1.0 : -1.0
            var top = root
            for along in stride(from: 0.0, to: length, by: 0.7) {
                top = Point(x: root.x + sin(lean) * along, y: root.y - cos(lean) * along)
                sheet.plot(top, along / length > 0.6 ? stemTop : stem)
            }
            for (index, at) in [0.25, 0.4, 0.55, 0.7].enumerated() {
                let start = Point(x: root.x + sin(lean) * length * at, y: root.y - cos(lean) * length * at)
                let outward = (index.isMultiple(of: 2) ? 1.0 : -1.0)
                var point = start, direction = Point(x: outward * 0.8, y: -0.6)
                for _ in 0..<Int.random(in: 10...16) {
                    point = Point(x: point.x + direction.x, y: point.y + direction.y)
                    direction.y += 0.06
                    sheet.plot(point, leaf)
                }
            }
            for _ in 0..<18 {
                let spot = Point(x: top.x + side * random(0...4), y: top.y + random(0...8))
                sheet.disc(spot, radius: random(0.8...1.5), plume.randomElement()!)
            }
        }
    }
}
