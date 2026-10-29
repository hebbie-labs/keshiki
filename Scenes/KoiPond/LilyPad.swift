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
            if !pads.contains(where: { pad.overlaps($0) }) { pads.append(pad) }
        }
        return pads
    }

    /// Drawn every frame, as the pads drift; the water casts their shadows. A pad lies flat on the water: lighter on
    /// the sun's side, a slit to the stem where the water shows through, fine veins and a slightly raised rim.
    func draw(on canvas: Canvas) {
        let top = position, notchAngle = notchAngle + turn
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
        let steps = Int(2.5 * .pi * radius)
        for step in 0..<steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            guard !inSlit(angle, notchAngle: notchAngle) else { continue }
            let sunny = (cos(angle - .pi * 1.25) + 1) / 2
            let color = sunny > 0.4 ? shade.rim.opacity(0.2 + 0.7 * sunny) : Color(0x0f2a14, alpha: 0.35 * (1 - sunny))
            canvas.disc(top.moved(by: edge(at: angle) - 0.6, heading: angle), radius: 0.5, color)
        }
    }

    /// Fine veins from the stem, lighter than the leaf, curving a little and forking halfway, fading towards the edge.
    private func drawVeins(on canvas: Canvas, at top: Point, notchAngle: Double) {
        for vein in 1..<16 {
            let angle = notchAngle + Double(vein) / 16 * 2 * .pi
            for step in stride(from: radius * 0.1, to: radius * 0.88, by: 0.9) {
                let along = step / radius, bend = sin(along * 3 + wobble + Double(vein)) * 0.05
                let color = shade.vein.mixed(with: shade.rim, 0.4).opacity(0.85 * (1 - along * 0.8))
                canvas.disc(top.moved(by: step, heading: angle + bend), radius: 0.4, color)
                if along > 0.5 {
                    canvas.disc(top.moved(by: step, heading: angle + bend + (along - 0.5) * 0.25), radius: 0.25, color)
                }
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
        for step in stride(from: 0.8, through: length, by: 0.35) {
            let t = step / length
            let color = base.mixed(with: tip, pow(t, 1.5)).mixed(with: Color(0x7a2a48), 0.18 * (1 - sunny))
            canvas.disc(center.moved(by: step, heading: heading), radius: width * pow(sin(.pi * pow(t, 0.75)), 0.8), color)
        }
        // A fine crease down the middle, fading towards the tip.
        for step in stride(from: 1.2, through: length * 0.8, by: 0.5) {
            canvas.disc(center.moved(by: step, heading: heading), radius: 0.22, Color(0xc8476f, alpha: 0.35 * blush * (1 - step / length)))
        }
    }
}
