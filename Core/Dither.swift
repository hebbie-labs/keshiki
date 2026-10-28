/// Ordered (Bayer) dithering, so smooth gradients turn into crisp pixel-art steps.
enum Dither {
    private static let bayer: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { ($0 + 0.5) / 16 }

    /// Rounds `value` (0...1) to one of `levels` steps, picking up or down by the pixel's threshold.
    static func quantize(_ value: Double, levels: Int, x: Int, y: Int) -> Double {
        let scaled = clamp(value, 0, 1) * Double(levels - 1)
        let lower = scaled.rounded(.down)
        let step = scaled - lower > bayer[(y & 3) * 4 + (x & 3)] ? lower + 1 : lower
        return step / Double(levels - 1)
    }
}
