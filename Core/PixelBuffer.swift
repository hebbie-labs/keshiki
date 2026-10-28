import CoreGraphics
import Foundation

/// An opaque 32-bit image a scene is drawn into, pixel by pixel, then shown scaled up with nearest-neighbour.
final class PixelBuffer {
    let width: Int
    let height: Int
    var pixels: [UInt32]

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

    init(width: Int, height: Int, color: Color = Color(0x000000)) {
        self.width = width
        self.height = height
        pixels = Array(repeating: color.packed, count: width * height)
    }

    @inline(__always)
    func plot(_ x: Int, _ y: Int, _ color: Color) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let index = y * width + x
        pixels[index] = color.isOpaque ? color.packed : color.over(pixels[index])
    }

    func plot(_ point: Point, _ color: Color) {
        plot(Int(point.x.rounded()), Int(point.y.rounded()), color)
    }

    func fillRect(_ origin: Point, width rectWidth: Int, height rectHeight: Int, _ color: Color) {
        let left = Int(origin.x.rounded()), top = Int(origin.y.rounded())
        let minX = max(0, left), maxX = min(width, left + rectWidth)
        let minY = max(0, top), maxY = min(height, top + rectHeight)
        // Entirely off the canvas, e.g. a heart above a koi at the top edge.
        guard minX < maxX, minY < maxY else { return }
        for y in minY..<maxY {
            for x in minX..<maxX { plot(x, y, color) }
        }
    }

    /// A filled circle made of whole pixels, so nothing is anti-aliased.
    func disc(_ center: Point, radius: Double, _ color: Color) {
        guard radius > 0 else { return }
        let cx = Int(center.x.rounded()), cy = Int(center.y.rounded())
        let reach = Int(radius.rounded(.up)), radiusSquared = radius * radius
        for dy in -reach...reach where Double(dy * dy) <= radiusSquared {
            let halfWidth = Int(sqrt(radiusSquared - Double(dy * dy)))
            let y = cy + dy
            guard y >= 0, y < height else { continue }
            let left = max(0, cx - halfWidth), right = min(width - 1, cx + halfWidth)
            guard left <= right else { continue }
            for x in left...right { plot(x, y, color) }
        }
    }

    /// A dotted ellipse, squashed vertically so ripples look like they lie on the water.
    func ring(_ center: Point, radius: Double, _ color: Color, squash: Double = 0.7) {
        let dots = max(10, Int(radius * 5))
        for i in 0..<dots {
            let angle = Double(i) / Double(dots) * 2 * .pi
            plot(Point(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius * squash), color)
        }
    }

    func heart(_ position: Point, opacity: Double) {
        let shape = [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."]
        let color = Color(0xf05a6e, alpha: opacity)
        for (row, line) in shape.enumerated() {
            for (column, cell) in line.enumerated() where cell == "X" {
                fillRect(Point(x: position.x + Double((column - 2) * 2), y: position.y + Double(row * 2)), width: 2, height: 2, color)
            }
        }
    }

    func cover(with color: Color) {
        pixels.withUnsafeMutableBufferPointer { buffer in
            for index in buffer.indices { buffer[index] = color.over(buffer[index]) }
        }
    }

    /// Copies in place, so no new pixel array is allocated every frame.
    func copyPixels(from other: PixelBuffer) {
        pixels.withUnsafeMutableBufferPointer { destination in
            other.pixels.withUnsafeBufferPointer { source in
                destination.baseAddress!.update(from: source.baseAddress!, count: min(source.count, destination.count))
            }
        }
    }

    func makeImage() -> CGImage? {
        let data = pixels.withUnsafeBytes { Data($0) } as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: Self.colorSpace, bitmapInfo: Self.bitmapInfo, provider: provider,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
