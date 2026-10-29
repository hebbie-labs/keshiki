import Foundation

/// Something a scene draws into, in design units (960 across the main display).
/// `DrawList` records shapes for the GPU each frame; `PixelBuffer` paints once on the CPU (the static floor).
protocol Canvas: AnyObject {
    func plot(_ point: Point, _ color: Color)
    func fillRect(_ origin: Point, width: Int, height: Int, _ color: Color)
    /// A rectangle of any size, not snapped to whole design units: for fine detail like the edge of a lily pad.
    func fill(_ origin: Point, width: Double, height: Double, _ color: Color)
    func disc(_ center: Point, radius: Double, _ color: Color)
    /// Lays a colour over the whole frame, e.g. the time-of-day tint.
    func cover(with color: Color)
    /// Marks where what swims under the water ends and what floats on it begins.
    func placeSurface()
    /// Marks where the scene's static overlay (painted once, e.g. lily pads) goes between the shapes.
    func placeOverlay()
}

extension Canvas {
    func heart(_ position: Point, opacity: Double) {
        let shape = [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."]
        let color = Color(0xf05a6e, alpha: opacity)
        for (row, line) in shape.enumerated() {
            for (column, cell) in line.enumerated() where cell == "X" {
                fillRect(Point(x: position.x + Double((column - 2) * 2), y: position.y + Double(row * 2)), width: 2, height: 2, color)
            }
        }
    }
}

/// Draws into another canvas with everything more transparent, e.g. a fish diving out of sight.
final class FadedCanvas: Canvas {
    private let base: Canvas
    private let amount: Double

    init(_ base: Canvas, amount: Double) {
        self.base = base
        self.amount = amount
    }

    private func faded(_ color: Color) -> Color { color.opacity(Double(color.weight) / 256 * amount) }
    func plot(_ point: Point, _ color: Color) { base.plot(point, faded(color)) }
    func fillRect(_ origin: Point, width: Int, height: Int, _ color: Color) { base.fillRect(origin, width: width, height: height, faded(color)) }
    func fill(_ origin: Point, width: Double, height: Double, _ color: Color) { base.fill(origin, width: width, height: height, faded(color)) }
    func disc(_ center: Point, radius: Double, _ color: Color) { base.disc(center, radius: radius, faded(color)) }
    func cover(with color: Color) { base.cover(with: faded(color)) }
    func placeSurface() { base.placeSurface() }
    func placeOverlay() { base.placeOverlay() }
}

/// Draws into another canvas with every colour pulled towards one, e.g. a fish swimming deep in murky water.
final class ShadedCanvas: Canvas {
    private let base: Canvas
    private let shade: Color
    private let amount: Double

    init(_ base: Canvas, toward shade: Color, amount: Double) {
        self.base = base
        self.shade = shade
        self.amount = amount
    }

    private func shaded(_ color: Color) -> Color { color.mixed(with: shade, amount).opacity(Double(color.weight) / 256) }
    func plot(_ point: Point, _ color: Color) { base.plot(point, shaded(color)) }
    func fillRect(_ origin: Point, width: Int, height: Int, _ color: Color) { base.fillRect(origin, width: width, height: height, shaded(color)) }
    func fill(_ origin: Point, width: Double, height: Double, _ color: Color) { base.fill(origin, width: width, height: height, shaded(color)) }
    func disc(_ center: Point, radius: Double, _ color: Color) { base.disc(center, radius: radius, shaded(color)) }
    func cover(with color: Color) { base.cover(with: color) }
    func placeSurface() { base.placeSurface() }
    func placeOverlay() { base.placeOverlay() }
}

/// Design units to device pixels: whole design pixels map to runs of device pixels, so nothing blurs.
struct PixelScale {
    let factor: Double

    func span(_ start: Double, length: Int) -> Range<Int> {
        let first = start.rounded()
        return Int((first * factor).rounded())..<Int(((first + Double(length)) * factor).rounded())
    }

    /// Where a point lands, to the nearest device pixel: shapes placed by their centre move smoothly.
    func pixel(_ value: Double) -> Int {
        Int((value * factor).rounded())
    }

    /// The device pixels a stretch covers, without snapping to whole design units.
    func fineSpan(_ start: Double, length: Double) -> Range<Int> {
        Int((start * factor).rounded())..<Int(((start + length) * factor).rounded())
    }
}
