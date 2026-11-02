import Foundation

struct LilyPad {
    /// Where the stem holds the pad; it drifts around this spot and springs back.
    let center: Point
    let radius: Double
    let notchAngle: Double
    let hasFlower: Bool
    /// Turns the lotus petals, so no two flowers look alike.
    let petalTurn: Double
    let shade: Shade
    /// Where the edge bulges a little, so no pad is a perfect circle.
    let wobble: Double
    var offset = Point(x: 0, y: 0)
    var drift = Point(x: 0, y: 0)
    var turn = 0.0
    var spin = 0.0

    var position: Point { Point(x: center.x + offset.x, y: center.y + offset.y) }

    private static let count = 13
    private static let placementAttempts = 600
    private static let minimumGap = 4.0
    /// A pad's colours: mostly greens, a few young ones still bronze.
    struct Shade {
        let leaf: Color
        let rim: Color
        let vein: Color
    }

    private static let shades = [
        Shade(leaf: Color(0x3b7a37), rim: Color(0x6fae5c), vein: Color(0x5e9a4e)),
        Shade(leaf: Color(0x2f6c36), rim: Color(0x5f9f55), vein: Color(0x4f8c48)),
        Shade(leaf: Color(0x4a7d33), rim: Color(0x86b45a), vein: Color(0x6a9a46)),
        Shade(leaf: Color(0x5d5a32), rim: Color(0x8c8650), vein: Color(0x756f40)),
    ]
    /// Half the opening of the slit running from the edge to the stem, in radians.
    private static let slit = 0.11
    /// The leaf is filled in rows this tall, in design units, so its edge stays smooth.
    private static let row = 0.5

    /// Pads may hang over the edges, like in a real pond.
    static func scatter(in size: SceneSize) -> [LilyPad] {
        var pads: [LilyPad] = []
        for _ in 0..<placementAttempts where pads.count < count {
            let pad = LilyPad(center: Point(x: random(-10...(size.width + 10)), y: random(-10...(size.height + 10))),
                              radius: random(18...44), notchAngle: random(0...(2 * .pi)),
                              hasFlower: chance(0.3), petalTurn: random(0...(2 * .pi)),
                              shade: chance(0.08) ? shades[3] : shades[Int.random(in: 0...2)], wobble: random(0...(2 * .pi)))
            if !pads.contains(where: { pad.overlaps($0) }), !Reeds.inNearCorner(pad.center, radius: pad.radius, size: size) { pads.append(pad) }
        }
        return pads
    }

    /// Drawn every frame, as the pads drift; the water casts their shadows. A pad lies flat on the water: lighter on
    /// the sun's side, a slit to the stem where the water shows through, fine veins and a slightly raised rim.
    func draw(on canvas: Canvas, lotus: Bool = false) {
        let top = position, notchAngle = notchAngle + turn
        if lotus { return drawLotusStyle(on: canvas, at: top, notchAngle: notchAngle) }
        drawLeaf(on: canvas, at: top, notchAngle: notchAngle)
        drawRim(on: canvas, at: top, notchAngle: notchAngle)
        drawVeins(on: canvas, at: top, notchAngle: notchAngle)
        canvas.disc(top, radius: 1.2, shade.leaf.mixed(with: Color(0x0f2a14), 0.4))
        if hasFlower { drawLotus(on: canvas, at: Point(x: top.x + radius * 0.15, y: top.y - radius * 0.1)) }
    }

    private func overlaps(_ other: LilyPad) -> Bool {
        center.distance(to: other.center) < radius + other.radius + Self.minimumGap
    }

    private func edge(at angle: Double) -> Double {
        radius * (1 + 0.035 * sin(angle * 3 + wobble) + 0.02 * sin(angle * 5 - wobble))
    }

    private func inSlit(_ angle: Double, notchAngle: Double) -> Bool {
        abs(angleDifference(from: notchAngle, to: angle)) < Self.slit
    }

    /// Row by row: each row's ends come from the (slightly wavy) edge, and the slit cuts its stretch out of the
    /// middle, worked out from the slit's two sides rather than pixel by pixel.
    private func drawLeaf(on canvas: Canvas, at top: Point, notchAngle: Double) {
        let reach = Int(radius) + 1  // design units
        let (lowSide, highSide) = (notchAngle - Self.slit, notchAngle + Self.slit)
        /// Where a row crosses one side of the slit; nil if that side runs away from the row.
        func crossing(_ side: Double, _ dy: Double) -> Double? {
            let rise = sin(side)
            guard abs(rise) > 1e-6, dy / rise > 0 else { return nil }
            return dy / rise * cos(side)
        }
        func fill(_ from: Double, _ to: Double, row: Int) {
            guard to - from > 0.2 else { return }
            let dy = Double(row) * Self.row
            // Lighter towards the far side, where the sun is.
            let color = shade.leaf.mixed(with: shade.rim, 0.22 * (0.5 - dy / radius / 2)).mixed(with: Color(0x10301a), 0.15 * (0.5 + dy / radius / 2))
            canvas.fill(Point(x: top.x + from, y: top.y + dy), width: to - from, height: Self.row, color)
        }
        let rows = Int(Double(reach) / Self.row)
        for row in -rows...rows {
            let dy = Double(row) * Self.row + Self.row / 2
            guard abs(dy) < radius else { continue }
            let half = (radius * radius - dy * dy).squareRoot()
            // The wavy edge may pull in past a row near the top or bottom; that row then has nothing on that side.
            let right = max(0, pow(edge(at: atan2(dy, half)), 2) - dy * dy).squareRoot()
            let left = -max(0, pow(edge(at: atan2(dy, -half)), 2) - dy * dy).squareRoot()
            var gapLow = Double.infinity, gapHigh = -Double.infinity
            switch (crossing(lowSide, dy), crossing(highSide, dy)) {
            case let (a?, b?): (gapLow, gapHigh) = (min(a, b), max(a, b))
            case let (a?, nil), let (nil, a?): (gapLow, gapHigh) = cos(notchAngle) > 0 ? (a, .infinity) : (-.infinity, a)
            case (nil, nil): break
            }
            if gapLow < right && gapHigh > left {
                fill(left, max(left, gapLow), row: row)
                fill(min(right, gapHigh), right, row: row)
            } else {
                fill(left, right, row: row)
            }
        }
    }

    /// The edge curls up a little: it catches the light on the sun's side and darkens on the other.
    private func drawRim(on canvas: Canvas, at top: Point, notchAngle: Double) {
        let steps = Int(2 * .pi * radius)
        for step in 0..<steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            guard !inSlit(angle, notchAngle: notchAngle) else { continue }
            let sunny = (cos(angle - .pi * 1.25) + 1) / 2
            let color = sunny > 0.4 ? shade.rim.opacity(0.2 + 0.7 * sunny) : Color(0x0f2a14, alpha: 0.35 * (1 - sunny))
            canvas.disc(top.moved(by: edge(at: angle) - 0.6, heading: angle), radius: 0.5, color)
        }
    }

    /// Fine veins from the stem, lighter than the leaf, curving a little, fading towards the edge.
    private func drawVeins(on canvas: Canvas, at top: Point, notchAngle: Double) {
        for vein in 1..<16 {
            let angle = notchAngle + Double(vein) / 16 * 2 * .pi
            for step in stride(from: radius * 0.1, to: radius * 0.88, by: 0.9) {
                let along = step / radius, bend = sin(along * 3 + wobble + Double(vein)) * 0.05
                let color = shade.vein.mixed(with: shade.rim, 0.4).opacity(0.85 * (1 - along * 0.8))
                canvas.disc(top.moved(by: step, heading: angle + bend), radius: 0.4, color)
            }
        }
    }

    /// A water lily seen from above: three rings of pointed petals, the outer ones lying open and long, the inner ones
    /// standing up short and pale, each blushing towards its tip and lit on the sun's side, around a golden heart
    /// of stamens. It casts a soft shadow on its pad.
    private func drawLotus(on canvas: Canvas, at center: Point) {
        let turn = petalTurn + self.turn
        canvas.disc(center.moved(by: 1.5, heading: .pi * 0.25), radius: 10.5, Color(0x0f2a14, alpha: 0.22))
        for ring in Self.lotusRings {
            for petal in 0..<ring.count {
                let angle = (Double(petal) + ring.offset) / Double(ring.count) * 2 * .pi + turn
                drawPetal(on: canvas, from: center, heading: angle, length: ring.length, width: ring.width, blush: ring.blush)
            }
        }
        canvas.disc(center, radius: 2.6, Color(0xf2b632))
        for stamen in 0..<10 {
            let angle = Double(stamen) / 10 * 2 * .pi + turn
            canvas.disc(center.moved(by: 2.2, heading: angle), radius: 0.5, stamen.isMultiple(of: 2) ? Color(0xffe27a) : Color(0xe8902a))
        }
        canvas.disc(center, radius: 0.9, Color(0xd9a12a))
    }

    private static let lotusRings: [(count: Int, offset: Double, length: Double, width: Double, blush: Double)] = [
        (10, 0, 10.5, 2.3, 1), (8, 0.5, 8, 2, 0.7), (6, 0.25, 5.5, 1.6, 0.35),
    ]

    /// A petal widens from its base, then narrows to a point: white at the base, pink towards the tip.
    private func drawPetal(on canvas: Canvas, from center: Point, heading: Double, length: Double, width: Double, blush: Double) {
        let sunny = (cos(heading - .pi * 1.25) + 1) / 2
        let base = Color(0xfbeef2), tip = Color(0xe2558a).mixed(with: base, 1 - blush)
        for step in stride(from: 0.8, through: length, by: 0.8) {
            let t = step / length
            let color = base.mixed(with: tip, pow(t, 1.5)).mixed(with: Color(0x7a2a48), 0.18 * (1 - sunny))
            canvas.disc(center.moved(by: step, heading: heading), radius: width * pow(sin(.pi * pow(t, 0.75)), 0.8), color)
        }
    }

    // Lotus pads in the style of Nagomi (see THIRD_PARTY_NOTICES.md): flat and dark, shaded across by the light,
    // a wide notch, a few dark veins and a pink star of a flower.

    private struct LotusLeaf {
        let base: Color, light: Color, shade: Color, vein: Color
    }

    private struct StarFlower {
        let outer: Color, inner: Color, light: Color, heart: Color, heartRim: Color
    }

    private static let lotusLeaves = [
        LotusLeaf(base: Color(0x285f3f), light: Color(0x316d4a), shade: Color(0x1f4e33), vein: Color(0x143424)),
        LotusLeaf(base: Color(0x24583a), light: Color(0x2d6544), shade: Color(0x1b472e), vein: Color(0x112f20)),
    ]
    private static let starFlowers = [
        StarFlower(outer: Color(0xf29aaa), inner: Color(0xffc4cc), light: Color(0xffe1e2), heart: Color(0xf2bd45), heartRim: Color(0xb96d31)),
        StarFlower(outer: Color(0xe985ac), inner: Color(0xfab7ce), light: Color(0xffdce6), heart: Color(0xf5c64b), heartRim: Color(0xbd7330)),
    ]
    private static let lotusNotch = 0.3
    private static let lotusVeins = 5
    /// Shading steps across the leaf, and the wedges it's built from.
    private static let lotusTones = 7
    private static let lotusWedges = 40

    private func drawLotusStyle(on canvas: Canvas, at top: Point, notchAngle: Double) {
        let leaf = Self.lotusLeaves[wobble < .pi ? 0 : 1]
        drawLotusLeaf(on: canvas, at: top, notchAngle: notchAngle, leaf: leaf)
        let start = notchAngle + Self.lotusNotch, span = 2 * .pi - 2 * Self.lotusNotch
        for vein in 1...Self.lotusVeins {
            let angle = start + Double(vein) / Double(Self.lotusVeins + 1) * span
            for step in stride(from: 0.0, through: radius * 0.68, by: 0.6) { canvas.disc(top.moved(by: step, heading: angle), radius: 0.4, leaf.vein) }
        }
        if hasFlower {
            let flower = Self.starFlowers[petalTurn < .pi ? 0 : 1]
            drawStarFlower(on: canvas, at: top.moved(by: radius * 0.18, heading: petalTurn), size: clamp(radius * 0.45, 12, 18), flower: flower)
        }
    }

    /// Wedges from the stem, each a tone lighter on the side the light comes from, filled row by row: in each row a
    /// wedge covers the stretch between where its two sides cross it.
    private func drawLotusLeaf(on canvas: Canvas, at top: Point, notchAngle: Double, leaf: LotusLeaf) {
        let start = notchAngle + Self.lotusNotch, span = 2 * .pi - 2 * Self.lotusNotch
        func tone(_ angle: Double) -> Color {
            let light = clamp(0.5 + cos(angle + 2.2) * 0.42 + sin(angle * 3 + wobble * 0.7) * 0.045, 0, 1)
            let step = (light * Double(Self.lotusTones - 1)).rounded() / Double(Self.lotusTones - 1)
            return step < 0.5 ? leaf.shade.mixed(with: leaf.base, step * 2) : leaf.base.mixed(with: leaf.light, (step - 0.5) * 2)
        }
        // Neighbouring wedges of the same tone merge; each wedge is kept within -pi...pi, split where it wraps.
        var wedges: [(from: Double, to: Double, color: Color)] = []
        for index in 0..<Self.lotusWedges {
            let from = start + Double(index) / Double(Self.lotusWedges) * span, to = from + span / Double(Self.lotusWedges)
            let color = tone((from + to) / 2)
            if let last = wedges.last, last.color == color, abs(last.to - from) < 1e-9 { wedges[wedges.count - 1].to = to } else { wedges.append((from, to, color)) }
        }
        var pieces: [(from: Double, to: Double, color: Color)] = []
        for wedge in wedges {
            var from = wedge.from.truncatingRemainder(dividingBy: 2 * .pi)
            if from > .pi { from -= 2 * .pi } else if from <= -.pi { from += 2 * .pi }
            let to = from + (wedge.to - wedge.from)
            if to > .pi {
                pieces.append((from, .pi, wedge.color))
                pieces.append((-.pi, to - 2 * .pi, wedge.color))
            } else {
                pieces.append((from, to, wedge.color))
            }
        }
        let row = 1.0
        for index in -Int(radius)...Int(radius) {
            let dy = Double(index) * row + row / 2
            guard abs(dy) < radius else { continue }
            let half = (radius * radius - dy * dy).squareRoot()
            let right = max(0, pow(edge(at: atan2(dy, half)), 2) - dy * dy).squareRoot()
            let left = -max(0, pow(edge(at: atan2(dy, -half)), 2) - dy * dy).squareRoot()
            // This row's half of the circle of angles: below the stem 0...pi, above it -pi...0.
            let (low, high) = dy > 0 ? (0.0, Double.pi) : (-Double.pi, 0.0)
            for piece in pieces {
                let from = max(piece.from, low), to = min(piece.to, high)
                guard from < to else { continue }
                let a = crossing(from, dy), b = crossing(to, dy)
                let x0 = max(left, min(a, b)), x1 = min(right, max(a, b))
                if x1 - x0 > 0.2 { canvas.fill(Point(x: top.x + x0, y: top.y + dy - row / 2), width: x1 - x0, height: row, piece.color) }
            }
        }
    }

    /// Where the ray from the stem at `angle` crosses the row `dy` below it (far off to the side where it runs flat).
    private func crossing(_ angle: Double, _ dy: Double) -> Double {
        let rise = sin(angle)
        guard abs(rise) > 1e-6 else { return cos(angle) > 0 ? 2 * radius : -2 * radius }
        return clamp(dy * cos(angle) / rise, -2 * radius, 2 * radius)
    }

    /// Two rings of pointed petals, every third lighter, around a golden heart, with a soft shadow on the pad.
    private func drawStarFlower(on canvas: Canvas, at center: Point, size: Double, flower: StarFlower) {
        let turn = petalTurn + self.turn
        canvas.disc(center.moved(by: 1.5, heading: .pi * 0.25), radius: size * 0.75, Color(0x0f2a14, alpha: 0.25))
        for (count, length, width, offset, color) in [(8, 1.0, 0.22, 0.0, flower.outer), (6, 0.66, 0.19, Double.pi / 6, flower.inner)] {
            for petal in 0..<count {
                let heading = turn + offset + Double(petal) / Double(count) * 2 * .pi
                let paint = petal % 3 == 0 ? flower.light : color
                for step in stride(from: size * 0.12, through: size * length, by: 0.5) {
                    let t = (step - size * 0.12) / (size * (length - 0.12))
                    canvas.disc(center.moved(by: step, heading: heading), radius: max(0.35, size * width * (1 - t)), paint)
                }
            }
        }
        canvas.disc(center, radius: size * 0.28, flower.heartRim)
        canvas.disc(center, radius: size * 0.18, flower.heart)
    }
}
