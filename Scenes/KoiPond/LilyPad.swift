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

    /// Pads may hang over the edges, like in a real pond.
    static func scatter(in size: SceneSize) -> [LilyPad] {
        var pads: [LilyPad] = []
        for _ in 0..<placementAttempts where pads.count < count {
            let pad = LilyPad(center: Point(x: random(-10...(size.width + 10)), y: random(-10...(size.height + 10))),
                              radius: random(18...44), notchAngle: random(0...(2 * .pi)),
                              hasFlower: chance(0.3), petalTurn: random(0...(2 * .pi)),
                              shade: chance(0.08) ? shades[3] : shades[Int.random(in: 0...2)], wobble: random(0...(2 * .pi)))
            if !pads.contains(where: { pad.overlaps($0) }) { pads.append(pad) }
        }
        return pads
    }

    /// Drawn every frame, as the pads drift; the water casts their shadows. A pad lies flat on the water: one colour,
    /// a slit to the stem where the water shows through, fine light veins and a slightly raised rim.
    func draw(on canvas: Canvas) {
        let top = position, notchAngle = notchAngle + turn
        drawLeaf(on: canvas, at: top, notchAngle: notchAngle)
        drawRim(on: canvas, at: top, notchAngle: notchAngle)
        drawVeins(on: canvas, at: top, notchAngle: notchAngle)
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
        let reach = Int(radius) + 1
        let (lowSide, highSide) = (notchAngle - Self.slit, notchAngle + Self.slit)
        /// Where a row crosses one side of the slit; nil if that side runs away from the row.
        func crossing(_ side: Double, _ dy: Double) -> Double? {
            let rise = sin(side)
            guard abs(rise) > 1e-6, dy / rise > 0 else { return nil }
            return dy / rise * cos(side)
        }
        func fill(_ from: Double, _ to: Double, row: Int) {
            let start = from.rounded()
            guard to - start >= 1 else { return }
            canvas.fillRect(Point(x: top.x.rounded() + start, y: top.y.rounded() + Double(row)), width: Int((to - start).rounded()), height: 1, shade.leaf)
        }
        for row in -reach...reach {
            let dy = Double(row) + 0.5
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

    /// The edge curls up a little and catches the light on the sun's side (the far side stays plain).
    private func drawRim(on canvas: Canvas, at top: Point, notchAngle: Double) {
        let steps = Int(2 * .pi * radius)
        for step in 0..<steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            guard !inSlit(angle, notchAngle: notchAngle) else { continue }
            let sunny = (cos(angle - .pi * 1.25) + 1) / 2
            guard sunny > 0.35 else { continue }
            canvas.plot(top.moved(by: edge(at: angle) - 0.8, heading: angle), shade.rim.opacity(0.25 + 0.6 * sunny))
        }
    }

    /// Fine veins from the stem, lighter than the leaf, fading out before the edge.
    private func drawVeins(on canvas: Canvas, at top: Point, notchAngle: Double) {
        for vein in 1..<10 {
            let angle = notchAngle + Double(vein) / 10 * 2 * .pi
            for step in stride(from: radius * 0.15, to: radius * 0.75, by: 1.6) {
                canvas.plot(top.moved(by: step, heading: angle), shade.vein.opacity(0.55 * (1 - step / radius)))
            }
        }
    }

    private func drawLotus(on canvas: Canvas, at center: Point) {
        for petal in 0..<8 {
            let angle = Double(petal) / 8 * 2 * .pi + petalTurn
            canvas.disc(center.moved(by: 6, heading: angle + turn), radius: 2.6, petal.isMultiple(of: 2) ? Color(0xe8578a) : Color(0xf39ab9))
        }
        for petal in 0..<5 {
            canvas.disc(center.moved(by: 3, heading: Double(petal) / 5 * 2 * .pi + petalTurn + turn + 0.3), radius: 2.2, Color(0xf8c3d6))
        }
        canvas.disc(center, radius: 2, Color(0xffcf4a))
        canvas.plot(center, Color(0xf08a24))
    }
}
