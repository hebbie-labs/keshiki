import Foundation

/// A living wallpaper: it moves on its own, draws itself as shapes over a painted backdrop, and reacts to clicks.
/// Positions are in design units (960 wide); the scene renders at `pixelScale` times that.
protocol LivingScene: AnyObject {
    var settings: KeshikiSettings { get set }
    var systemDark: Bool { get set }
    var pixelWidth: Int { get }
    var pixelHeight: Int { get }
    var pixelScale: Double { get }

    func advance(by dt: Double)
    /// A freshly painted backdrop when it changed since the last call, else nil.
    /// The scene drops its copy, so the pixels live only on the GPU afterwards.
    func takeNewBackdrop() -> PixelBuffer?
    /// Like the backdrop, but drawn above the shapes before `placeOverlay()` (transparent where empty).
    func takeNewOverlay() -> PixelBuffer?
    /// The light net to lay over the backdrop this frame, if the scene has one.
    var caustics: CausticsFrame? { get }
    func draw(on canvas: Canvas, at date: Date)
    /// A click on the desktop; `spot` runs 0...1 across the display, origin top-left.
    func touch(at spot: Point, withOption: Bool)
}
