import Foundation

/// Something a scene draws into, in design units (the scene's 960-wide coordinate space).
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
