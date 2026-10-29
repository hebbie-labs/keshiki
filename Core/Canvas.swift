import Foundation

/// Something a scene draws into, in design units (960 across the main display).
/// `DrawList` records shapes for the GPU each frame; `PixelBuffer` paints once on the CPU (the static floor).
protocol Canvas: AnyObject {
    func plot(_ point: Point, _ color: Color)
    func fillRect(_ origin: Point, width: Int, height: Int, _ color: Color)
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
    func disc(_ center: Point, radius: Double, _ color: Color) { base.disc(center, radius: radius, faded(color)) }
    func cover(with color: Color) { base.cover(with: faded(color)) }
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

    func pixel(_ value: Double) -> Int {
        Int((value.rounded() * factor).rounded())
    }
}
