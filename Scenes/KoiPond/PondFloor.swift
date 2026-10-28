import Foundation

/// Paints the bare floor once: silt, pebbles and cushions of moss and algae. The plants that move are drawn live
/// (`Seagrass`, and the reeds standing at the edge). The water over it, and the light and shadows
/// in it, are drawn live at the floor's depth.
enum PondFloor {
    private static let cushions = 46

    /// `scale` is device pixels per design unit; per-pixel effects are computed at full device resolution.
    static func paint(size: SceneSize, scale: Double, waterName: String) -> PixelBuffer {
        let palette = WaterPalette.named(waterName)
        let canvas = PixelBuffer(width: Int((size.width * scale).rounded()), height: Int((size.height * scale).rounded()),
                                 scale: scale, color: palette.floor)
        paintSilt(on: canvas, palette: palette, scale: scale)
        paintPebbles(on: canvas, size: size, palette: palette)
        for _ in 0..<cushions { paintCushion(on: canvas, at: plantSpot(in: size), palette: palette) }
        return canvas
    }

    /// 0 at the shallow edges, 1 in the deep middle, with a little unevenness.
    static func depth(x: Double, y: Double, size: SceneSize) -> Double {
        let edgeDistance = min(x, size.width - x, y, size.height - y)
        let bowl = clamp(edgeDistance / (size.height * 0.42), 0, 1)
        let unevenness = (sin(x * 0.021 + y * 0.013) + sin(x * 0.008 - y * 0.017)) * 0.08
        let value = clamp(bowl + unevenness, 0, 1)
        return value * value * (3 - 2 * value)
    }

    private static func paintSilt(on canvas: PixelBuffer, palette: WaterPalette, scale: Double) {
        for y in 0..<canvas.height {
            for x in 0..<canvas.width {
                let fx = Double(x) / scale, fy = Double(y) / scale
                let mottling = (sin(fx * 0.05 + sin(fy * 0.03) * 2) + sin(fy * 0.045 - fx * 0.02) + 2) / 4
                let level = Dither.quantize(mottling * 0.55, levels: 4, x: x, y: y)
                canvas.plot(x, y, palette.silt.opacity(level))
            }
        }
    }

    private static func paintPebbles(on canvas: PixelBuffer, size: SceneSize, palette: WaterPalette) {
        for _ in 0..<900 {
            let spot = chance(0.6) ? plantSpot(in: size) : size.randomPoint(marginX: 0)
            canvas.fillRect(spot, width: Int.random(in: 1...3), height: Int.random(in: 1...2), palette.pebbles.randomElement()!.opacity(random(0.4...0.9)))
        }
    }

    /// Mostly along the shallow edges, where the light reaches the floor.
    private static func plantSpot(in size: SceneSize) -> Point {
        guard chance(0.8) else { return size.randomPoint(marginX: 60) }
        let band = random(0...110)
        switch Int.random(in: 0..<4) {
        case 0: return Point(x: band, y: random(0...size.height))
        case 1: return Point(x: size.width - band, y: random(0...size.height))
        case 2: return Point(x: random(0...size.width), y: band)
        default: return Point(x: random(0...size.width), y: size.height - band)
        }
    }

    /// A soft cushion of moss (greens) or algae (olives), domed: lighter on top, darker at the rim.
    private static func paintCushion(on canvas: PixelBuffer, at center: Point, palette: WaterPalette) {
        let radius = random(5...16)
        let colors = chance(0.6) ? Array(palette.plants[0...3])
            : [Color(0x4e5a2a), Color(0x6b7a3a), Color(0x8a9a48), Color(0xa8b860)].map { $0.mixed(with: palette.silt, 0.25) }
        for _ in 0..<Int(radius * radius * 0.8) {
            let reach = Double.random(in: 0...1).squareRoot() * radius, angle = random(0...(2 * .pi))
            let dome = 1 - reach / radius
            let shade = min(colors.count - 1, Int(dome * Double(colors.count - 1) + random(0...0.9)))
            canvas.disc(Point(x: center.x + cos(angle) * reach * 1.3, y: center.y + sin(angle) * reach), radius: random(0.7...1.6), colors[shade])
        }
    }
}
