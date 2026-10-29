import CoreGraphics
import Foundation

/// An opaque 32-bit image painted on the CPU. Used for things drawn once, like a scene's static floor.
final class PixelBuffer: Canvas {
    let width: Int
    let height: Int
    let scale: PixelScale
    var pixels: [UInt32]

    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

    /// `color: nil` starts fully transparent, for overlays; drawn pixels are always opaque.
    init(width: Int, height: Int, scale: Double = 1, color: Color? = Color(0x000000)) {
        self.width = width
        self.height = height
        self.scale = PixelScale(factor: scale)
        pixels = Array(repeating: color?.packed ?? 0, count: width * height)
    }

    /// One device pixel, ignoring the scale; for per-pixel loops.
    @inline(__always)
    func plot(_ x: Int, _ y: Int, _ color: Color) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let index = y * width + x
        pixels[index] = color.isOpaque ? color.packed : color.over(pixels[index])
    }

    func plot(_ point: Point, _ color: Color) {
        fillRect(point, width: 1, height: 1, color)
    }

    func fillRect(_ origin: Point, width rectWidth: Int, height rectHeight: Int, _ color: Color) {
        let columns = scale.span(origin.x, length: rectWidth).clamped(to: 0..<width)
        let rows = scale.span(origin.y, length: rectHeight).clamped(to: 0..<height)
        for y in rows {
            for x in columns { plot(x, y, color) }
        }
    }

    func fill(_ origin: Point, width rectWidth: Double, height rectHeight: Double, _ color: Color) {
        let columns = scale.fineSpan(origin.x, length: rectWidth).clamped(to: 0..<width)
        let rows = scale.fineSpan(origin.y, length: rectHeight).clamped(to: 0..<height)
        for y in rows {
            for x in columns { plot(x, y, color) }
        }
    }

    /// A filled circle made of whole pixels, so nothing is anti-aliased.
    func disc(_ center: Point, radius: Double, _ color: Color) {
        let radius = radius * scale.factor
        guard radius > 0 else { return }
        let cx = scale.pixel(center.x), cy = scale.pixel(center.y)
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

    func cover(with color: Color) {
        pixels.withUnsafeMutableBufferPointer { buffer in
            for index in buffer.indices { buffer[index] = color.over(buffer[index]) }
        }
    }

    func placeSurface() {}

    func placeOverlay() {}

    func makeImage() -> CGImage? {
        let data = pixels.withUnsafeBytes { Data($0) } as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: Self.colorSpace, bitmapInfo: Self.bitmapInfo, provider: provider,
                       decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
