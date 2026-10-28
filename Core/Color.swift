import Foundation

/// An sRGB colour with opacity, pre-packed for fast blending into a `PixelBuffer`.
struct Color: Equatable {
    let red: UInt32
    let green: UInt32
    let blue: UInt32
    /// Opacity as a 0...256 weight, so blending needs no floating point.
    let weight: UInt32

    init(_ hex: UInt32, alpha: Double = 1) {
        self.init(red: hex >> 16 & 0xff, green: hex >> 8 & 0xff, blue: hex & 0xff, alpha: alpha)
    }

    init(red: UInt32, green: UInt32, blue: UInt32, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        weight = UInt32(clamp(alpha, 0, 1) * 256)
    }

    var isOpaque: Bool { weight >= 256 }

    var packed: UInt32 { 0xff00_0000 | red << 16 | green << 8 | blue }

    func opacity(_ alpha: Double) -> Color {
        Color(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// Linear blend towards another colour, for baking gradients.
    func mixed(with other: Color, _ amount: Double) -> Color {
        let t = clamp(amount, 0, 1)
        func channel(_ a: UInt32, _ b: UInt32) -> UInt32 { UInt32(Double(a) + (Double(b) - Double(a)) * t) }
        return Color(red: channel(red, other.red), green: channel(green, other.green), blue: channel(blue, other.blue))
    }

    /// This colour laid over an opaque packed pixel.
    @inline(__always)
    func over(_ pixel: UInt32) -> UInt32 {
        let keep = 256 - weight
        let r = ((pixel >> 16 & 0xff) * keep + red * weight) >> 8
        let g = ((pixel >> 8 & 0xff) * keep + green * weight) >> 8
        let b = ((pixel & 0xff) * keep + blue * weight) >> 8
        return 0xff00_0000 | r << 16 | g << 8 | b
    }
}
