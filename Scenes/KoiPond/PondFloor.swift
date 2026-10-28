import Foundation

/// Paints the bare floor once: silt, pebbles and plants. The water over it, and the light and shadows
/// in it, are drawn live at the floor's depth.
enum PondFloor {
    private static let plantClusters = 42

    /// `scale` is device pixels per design unit; per-pixel effects are computed at full device resolution.
    static func paint(size: SceneSize, scale: Double, waterName: String) -> PixelBuffer {
        let palette = WaterPalette.named(waterName)
        let canvas = PixelBuffer(width: Int((size.width * scale).rounded()), height: Int((size.height * scale).rounded()),
                                 scale: scale, color: palette.floor)
        paintSilt(on: canvas, palette: palette, scale: scale)
        paintPebbles(on: canvas, size: size, palette: palette)
        for _ in 0..<plantClusters { paintPlant(on: canvas, at: plantSpot(in: size), palette: palette) }
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

    /// An irregular clump of sprigs: curved stems with leaves that get lighter towards the tips.
    private static func paintPlant(on canvas: PixelBuffer, at center: Point, palette: WaterPalette) {
        let radius = random(14...38)
        for _ in 0..<Int(radius * 1.3) {
            let root = center.jittered(radius * 0.35)
            paintSprig(on: canvas, from: root, length: random(radius * 0.4...radius * 1.1), heading: random(0...(2 * .pi)), palette: palette)
        }
    }

    private static func paintSprig(on canvas: PixelBuffer, from root: Point, length: Double, heading: Double, palette: WaterPalette) {
        let curl = random(-0.06...0.06)
        var point = root, direction = heading
        for step in 0..<Int(length) {
            let progress = Double(step) / length
            point = point.moved(by: 1, heading: direction)
            direction += curl
            canvas.plot(point, palette.plants[0])
            for side in [-1.0, 1.0] where chance(0.7) {
                let shade = min(palette.plants.count - 1, 1 + Int(progress * Double(palette.plants.count - 1) + random(0...1.5)))
                let leaf = point.moved(by: random(1.5...3.5), heading: direction + side * random(0.8...1.5))
                canvas.disc(leaf, radius: random(1.0...2.4) * (1.25 - progress * 0.5), palette.plants[shade])
            }
        }
    }
}
