import simd

/// One shape for the GPU, already in device pixels. Must match `Primitive` in the shader.
struct Primitive {
    /// minX, minY, maxX, maxY of the quad to draw.
    var bounds: SIMD4<Float>
    /// Straight (not premultiplied) RGBA.
    var color: SIMD4<Float>
    /// Disc centre x, y, radius, and 1 for a disc or 0 for a plain rectangle.
    var disc: SIMD4<Float>
}

/// Records what a scene draws each frame as a flat list of rectangles and discs for the GPU.
final class DrawList: Canvas {
    let width: Int
    let height: Int
    let scale: PixelScale
    private(set) var primitives: [Primitive] = []
    /// How many shapes swim under the water; nil if the scene has no surface.
    private(set) var surfaceIndex: Int?
    /// How many shapes go below the overlay; nil if the scene didn't place one.
    private(set) var overlayIndex: Int?
    /// Colours laid over the whole finished frame, like the light of the time of day, in order.
    private(set) var covers: [Color] = []

    init(width: Int, height: Int, scale: Double) {
        self.width = width
        self.height = height
        self.scale = PixelScale(factor: scale)
        primitives.reserveCapacity(16_000)
    }

    func reset() {
        primitives.removeAll(keepingCapacity: true)
        surfaceIndex = nil
        overlayIndex = nil
        covers.removeAll(keepingCapacity: true)
    }

    func placeSurface() {
        surfaceIndex = primitives.count
    }

    func placeOverlay() {
        overlayIndex = primitives.count
    }

    func plot(_ point: Point, _ color: Color) {
        fillRect(point, width: 1, height: 1, color)
    }

    func fillRect(_ origin: Point, width rectWidth: Int, height rectHeight: Int, _ color: Color) {
        let columns = scale.span(origin.x, length: rectWidth), rows = scale.span(origin.y, length: rectHeight)
        guard columns.upperBound > 0, rows.upperBound > 0, columns.lowerBound < width, rows.lowerBound < height else { return }
        append(SIMD4(Float(columns.lowerBound), Float(rows.lowerBound), Float(columns.upperBound), Float(rows.upperBound)), color, disc: .zero)
    }

    func fill(_ origin: Point, width rectWidth: Double, height rectHeight: Double, _ color: Color) {
        let columns = scale.fineSpan(origin.x, length: rectWidth), rows = scale.fineSpan(origin.y, length: rectHeight)
        guard !columns.isEmpty, !rows.isEmpty, columns.upperBound > 0, rows.upperBound > 0, columns.lowerBound < width, rows.lowerBound < height else { return }
        append(SIMD4(Float(columns.lowerBound), Float(rows.lowerBound), Float(columns.upperBound), Float(rows.upperBound)), color, disc: .zero)
    }

    /// Same pixels as `PixelBuffer.disc`: the shader repeats its row-by-row test.
    func disc(_ center: Point, radius: Double, _ color: Color) {
        let radius = radius * scale.factor
        guard radius > 0 else { return }
        let cx = Float(scale.pixel(center.x)), cy = Float(scale.pixel(center.y)), reach = Float(radius.rounded(.up))
        guard cx + reach >= 0, cy + reach >= 0, cx - reach < Float(width), cy - reach < Float(height) else { return }
        append(SIMD4(cx - reach, cy - reach, cx + reach + 1, cy + reach + 1), color, disc: SIMD4(cx, cy, Float(radius), 1))
    }

    func cover(with color: Color) {
        covers.append(color)
    }

    private func append(_ bounds: SIMD4<Float>, _ color: Color, disc: SIMD4<Float>) {
        guard color.weight > 0 else { return }
        let rgba = SIMD4(Float(color.red), Float(color.green), Float(color.blue), Float(color.weight) * 255 / 256) / 255
        primitives.append(Primitive(bounds: bounds, color: rgba, disc: disc))
    }
}
