import Foundation

/// Paints the bare floor once: silt, pebbles and cushions of moss and algae. The plants that move are drawn live
/// (the plant rosettes, and the reeds standing at the edge). The water over it, and the light and shadows
/// in it, are drawn live at the floor's depth.
enum PondFloor {
    private static let cushions = 46
    private static let fallenLeaves = 160
    /// How far the bank runs in from the edge, in design units, give or take its wobble.
    private static let bankWidth = 26.0
    private static let stones = 220

    /// `scale` is device pixels per design unit; per-pixel effects are computed at full device resolution.
    static func paint(size: SceneSize, scale: Double, waterName: String) -> PixelBuffer {
        let palette = WaterPalette.named(waterName)
        let canvas = PixelBuffer(width: Int((size.width * scale).rounded()), height: Int((size.height * scale).rounded()),
                                 scale: scale, color: palette.floor)
        paintSilt(on: canvas, palette: palette, scale: scale)
        paintBank(on: canvas, palette: palette, scale: scale)
        paintPebbles(on: canvas, size: size, palette: palette)
        if palette.litter.isEmpty { paintStones(on: canvas, size: size, palette: palette) }
        for _ in 0..<(palette.litter.isEmpty ? 0 : fallenLeaves) { paintLeaf(on: canvas, at: size.randomPoint(marginX: 0), palette: palette) }
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

    /// The bank all round: the floor slopes up into packed earth, lighter where it's drier, and a line of stones
    /// lies along its foot.
    private static func paintBank(on canvas: PixelBuffer, palette: WaterPalette, scale: Double) {
        let width = Double(canvas.width) / scale, height = Double(canvas.height) / scale
        let earth = palette.pebbles[1].mixed(with: palette.floor, 0.4), dry = palette.pebbles[2]
        func foot(_ along: Double) -> Double { bankWidth * (1 + 0.3 * sin(along * 0.031) + 0.15 * sin(along * 0.11 + 2)) }
        for y in 0..<canvas.height {
            for x in 0..<canvas.width {
                let fx = Double(x) / scale, fy = Double(y) / scale
                let distances = [(fx, fy), (width - fx, fy + 300), (fy, fx + 600), (height - fy, fx + 900)]
                guard let (distance, along) = distances.min(by: { $0.0 < $1.0 }) else { continue }
                let reach = foot(along)
                guard distance < reach else { continue }
                let up = 1 - distance / reach
                let grain = hash(x / 2, y / 2)
                let level = Dither.quantize(up * 0.6 + grain * 0.25, levels: 5, x: x, y: y)
                canvas.plot(x, y, earth.mixed(with: dry, level * 0.8).opacity(min(1, up * 3)))
            }
        }
        for edge in 0..<4 {
            let length = edge < 2 ? height : width
            var along = random(0...6)
            while along < length {
                let offset = Double(edge) * 300, inward = foot(along + offset) - random(0...4)
                let spot = switch edge {
                case 0: Point(x: inward, y: along)
                case 1: Point(x: width - inward, y: along)
                case 2: Point(x: along, y: inward)
                default: Point(x: along, y: height - inward)
                }
                let radius = random(1.8...4.2), color = palette.pebbles.randomElement()!
                canvas.disc(spot.moved(by: 0.8, heading: 1.2), radius: radius, palette.silt.mixed(with: Color(0x000000), 0.5).opacity(0.5))
                canvas.disc(spot, radius: radius, color)
                canvas.disc(spot.moved(by: radius * 0.35, heading: .pi * 1.25), radius: radius * 0.45, color.mixed(with: Color(0xffffff), 0.2))
                along += radius * random(1.2...2.2)
            }
        }
    }

    private static func paintPebbles(on canvas: PixelBuffer, size: SceneSize, palette: WaterPalette) {
        for _ in 0..<900 {
            let spot = chance(0.6) ? plantSpot(in: size) : size.randomPoint(marginX: 0)
            canvas.fillRect(spot, width: Int.random(in: 1...3), height: Int.random(in: 1...2), palette.pebbles.randomElement()!.opacity(random(0.4...0.9)))
        }
    }

    /// Rounded stones on clear water's gravel: lit on the sun's side, a dark crescent on the other.
    private static func paintStones(on canvas: PixelBuffer, size: SceneSize, palette: WaterPalette) {
        for _ in 0..<stones {
            let spot = size.randomPoint(marginX: 0), radius = random(1.2...3.5)
            let color = palette.pebbles.randomElement()!
            canvas.disc(spot.moved(by: 0.6, heading: 1.2), radius: radius, palette.silt.mixed(with: Color(0x000000), 0.45).opacity(0.5))
            canvas.disc(spot, radius: radius, color)
            canvas.disc(spot.moved(by: radius * 0.35, heading: .pi * 1.25), radius: radius * 0.5, color.mixed(with: Color(0xffffff), 0.25))
        }
    }

    /// A leaf that sank to the bottom: a pointed oval with a midrib, darker the longer it has lain there.
    private static func paintLeaf(on canvas: PixelBuffer, at spot: Point, palette: WaterPalette) {
        let length = random(3...6), heading = random(0...(2 * .pi))
        let color = palette.litter.randomElement()!.mixed(with: palette.silt, random(0...0.5)).opacity(random(0.6...0.95))
        for step in stride(from: -length, through: length, by: 0.5) {
            let t = step / length
            canvas.disc(spot.moved(by: step, heading: heading), radius: length * 0.42 * (1 - t * t), color)
        }
        for step in stride(from: -length, through: length, by: 0.5) {
            canvas.disc(spot.moved(by: step, heading: heading), radius: 0.25, color.mixed(with: palette.silt, 0.6))
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

    /// A soft cushion of moss (greens) or algae (olives), painted pixel by pixel: an uneven outline that fades out
    /// at the edge, domed (dark at the rim, lit on the side towards the light) and clumpy all over.
    private static func paintCushion(on canvas: PixelBuffer, at center: Point, palette: WaterPalette) {
        let radius = random(6...18)
        let colors = chance(0.6) ? Array(palette.plants[0...3])
            : [Color(0x4e5a2a), Color(0x6b7a3a), Color(0x8a9a48), Color(0xa8b860)].map { $0.mixed(with: palette.silt, 0.25) }
        let lobes = (random(0...6.3), random(0...6.3), Double.random(in: 0.05...0.12))
        let scale = canvas.scale.factor
        let reach = Int(radius * 1.5 * scale)
        let cx = Int(center.x * scale), cy = Int(center.y * scale)
        for y in (cy - reach)...(cy + reach) {
            for x in (cx - reach)...(cx + reach) {
                let dx = (Double(x - cx)) / scale, dy = (Double(y - cy)) / scale
                let angle = atan2(dy, dx * 0.77)
                let edge = radius * (1 + lobes.2 * sin(angle * 2 + lobes.0) + 0.07 * sin(angle * 5 + lobes.1) + 0.04 * sin(angle * 11 + lobes.0))
                let distance = hypot(dx * 0.77, dy) / edge
                guard distance < 1 else { continue }
                // Clumps two device pixels across, so it reads as moss rather than as noise.
                let clump = hash(x / 2, y / 2)
                let dome = 1 - distance * distance
                let lit = clamp(dome * 0.8 + (-dx * 0.2 - dy * 0.98) / radius * 0.35 + (clump - 0.5) * 0.5, 0, 0.999)
                let fade = min(1, (1 - distance) * 4) * (0.75 + 0.25 * clump)
                canvas.plot(x, y, colors[Int(lit * Double(colors.count))].opacity(fade))
            }
        }
    }

    /// A steady pseudo-random 0..<1 per cell.
    private static func hash(_ x: Int, _ y: Int) -> Double {
        let value = sin(Double(x) * 12.9898 + Double(y) * 78.233) * 43758.5453
        return value - value.rounded(.down)
    }
}
