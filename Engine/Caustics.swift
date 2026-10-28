import Foundation

/// The bright, wobbling net of light on the pond floor. Precomputed once as a seamless looping tile.
enum Caustics {
    private static let tileSize = 256
    private static let frameCount = 32
    private static let cellCount = 30
    private static let framesPerSecond = 8.0
    private static let warpStrength = 9.0
    private static let faint = Color(0xeafff5, alpha: 0.07)
    private static let bright = Color(0xeafff5, alpha: 0.17)

    /// Brightness 0, 1 or 2 per pixel, per frame.
    private static let frames: [[UInt8]] = makeFrames()

    static func draw(on canvas: PixelBuffer, time: Double) {
        let frame = frames[Int(time * framesPerSecond) % frameCount]
        let drift = Int(time * 2)
        let mask = tileSize - 1
        let width = canvas.width
        canvas.pixels.withUnsafeMutableBufferPointer { pixels in
            for y in 0..<canvas.height {
                let row = ((y + drift / 2) & mask) * tileSize
                for x in 0..<width {
                    switch frame[row + ((x + drift) & mask)] {
                    case 1: pixels[y * width + x] = faint.over(pixels[y * width + x])
                    case 2: pixels[y * width + x] = bright.over(pixels[y * width + x])
                    default: break
                    }
                }
            }
        }
    }

    /// Lines appear where a pixel is about equally close to two cell centres (Voronoi edges).
    /// Each centre circles slowly, completing one loop per animation cycle, so the tile loops seamlessly.
    private static func makeFrames() -> [[UInt8]] {
        let size = Double(tileSize)
        let cells = (0..<cellCount).map { _ in
            (center: Point(x: random(0...size), y: random(0...size)), radius: random(4...11), phase: random(0...(2 * .pi)))
        }
        return (0..<frameCount).map { frame in
            let turn = Double(frame) / Double(frameCount) * 2 * .pi
            let centres = cells.map { $0.center.moved(by: $0.radius, heading: turn + $0.phase) }
            var tile = [UInt8](repeating: 0, count: tileSize * tileSize)
            for y in 0..<tileSize {
                for x in 0..<tileSize {
                    let edge = distanceToCellEdge(warped(x, y, turn: turn), centres: centres, wrap: size)
                    tile[y * tileSize + x] = edge < 0.9 ? 2 : edge < 2.1 ? 1 : 0
                }
            }
            return tile
        }
    }

    /// Bends straight cell edges into wavy lines; whole sine periods per tile keep it seamless.
    private static func warped(_ x: Int, _ y: Int, turn: Double) -> Point {
        let unit = 2 * Double.pi / Double(tileSize)
        let fx = Double(x), fy = Double(y)
        return Point(x: fx + sin(fy * unit * 3 + turn) * warpStrength + sin(fy * unit * 7 - turn) * warpStrength * 0.4,
                     y: fy + sin(fx * unit * 4 - turn) * warpStrength + sin(fx * unit * 9 + turn) * warpStrength * 0.4)
    }

    private static func distanceToCellEdge(_ point: Point, centres: [Point], wrap: Double) -> Double {
        var nearest = Double.infinity, second = Double.infinity
        for centre in centres {
            var dx = abs(point.x - centre.x).truncatingRemainder(dividingBy: wrap)
            var dy = abs(point.y - centre.y).truncatingRemainder(dividingBy: wrap)
            dx = min(dx, wrap - dx)
            dy = min(dy, wrap - dy)
            let distance = (dx * dx + dy * dy).squareRoot()
            if distance < nearest { second = nearest; nearest = distance } else if distance < second { second = distance }
        }
        return second - nearest
    }
}
