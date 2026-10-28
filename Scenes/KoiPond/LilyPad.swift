import Foundation

struct LilyPad {
    /// Where the stem holds the pad; it drifts around this spot and springs back.
    let center: Point
    let radius: Double
    let notchAngle: Double
    let hasFlower: Bool
    /// Turns the lotus petals, so no two flowers look alike.
    let petalTurn: Double
    var offset = Point(x: 0, y: 0)
    var drift = Point(x: 0, y: 0)
    var turn = 0.0
    var spin = 0.0

    var position: Point { Point(x: center.x + offset.x, y: center.y + offset.y) }

    private static let count = 13
    private static let placementAttempts = 600
    private static let minimumGap = 4.0
    private static let leaf = Color(0x2d6a3a)
    private static let leafLight = Color(0x3c8246)
    private static let rim = Color(0x5fa45f)
    private static let vein = Color(0x22552f)

    /// Pads may hang over the edges, like in a real pond.
    static func scatter(in size: SceneSize) -> [LilyPad] {
        var pads: [LilyPad] = []
        for _ in 0..<placementAttempts where pads.count < count {
            let pad = LilyPad(center: Point(x: random(-10...(size.width + 10)), y: random(-10...(size.height + 10))),
                              radius: random(18...44), notchAngle: random(0...(2 * .pi)),
                              hasFlower: chance(0.3), petalTurn: random(0...(2 * .pi)))
            if !pads.contains(where: { pad.overlaps($0) }) { pads.append(pad) }
        }
        return pads
    }

    /// Drawn every frame, as the pads drift; the water casts their shadows.
    func draw(on canvas: Canvas) {
        let top = position, notchAngle = notchAngle + turn
        canvas.disc(top, radius: radius, Self.leaf)
        canvas.disc(Point(x: top.x - radius * 0.12, y: top.y - radius * 0.12), radius: radius * 0.8, Self.leafLight)
        drawRim(on: canvas, at: top)
        drawVeins(on: canvas, at: top, notchAngle: notchAngle)
        drawNotch(on: canvas, at: top, notchAngle: notchAngle)
        if hasFlower { drawLotus(on: canvas, at: Point(x: top.x + radius * 0.15, y: top.y - radius * 0.1)) }
    }

    private func overlaps(_ other: LilyPad) -> Bool {
        center.distance(to: other.center) < radius + other.radius + Self.minimumGap
    }

    /// Sunlight catches the upper-left edge.
    private func drawRim(on canvas: Canvas, at top: Point) {
        // About one design pixel apart along the arc: no gaps, no doubled pixels.
        for step in 0..<Int(radius * 2.4) {
            let angle = Double.pi * 0.9 + Double(step) / (radius * 2.4) * Double.pi * 0.9
            canvas.plot(top.moved(by: radius - 1, heading: angle), Self.rim)
        }
    }

    private func drawVeins(on canvas: Canvas, at top: Point, notchAngle: Double) {
        for vein in 0..<9 {
            let angle = notchAngle + 0.5 + Double(vein) * 0.66
            for step in stride(from: 3.0, to: radius - 2, by: 1.3) { canvas.plot(top.moved(by: step, heading: angle), Self.vein) }
        }
    }

    private func drawNotch(on canvas: Canvas, at top: Point, notchAngle: Double) {
        for step in stride(from: 1.0, to: radius + 1, by: 1) {
            let width = max(1.0, step * 0.3)
            canvas.disc(top.moved(by: step, heading: notchAngle), radius: width / 2, Color(0x1f5a48))
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
