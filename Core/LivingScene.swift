import Foundation

/// A living wallpaper: it moves on its own, draws itself as shapes over a painted backdrop, and reacts to clicks.
/// Positions are in design units (960 across the main display); the scene renders at `pixelScale` times that.
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
    /// The water over the backdrop, if the scene has any.
    var water: WaterSurface? { get }
    /// Plants standing up out of the water, painted once; nil if the scene has none (or already handed them over).
    func takeNewStanding() -> Standing?
    func draw(on canvas: Canvas, at date: Date)
    /// A click on the desktop; `spot` runs 0...1 across the display, origin top-left.
    func touch(at spot: Point, withOption: Bool)
}

extension LivingScene {
    func takeNewStanding() -> Standing? { nil }
}

/// Things standing upright out of the water, like reeds along the edge: sprites cut from one painted sheet, each
/// rooted at a point of the scene. `WaterStage` stands them up in 3D, facing the camera, and sways them in the wind.
struct Standing {
    struct Sprite {
        /// Where it stands, in design units.
        let root: Point
        /// Its cell on the sheet, in the sheet's pixels; the root is at the cell's bottom middle.
        let x: Int, y: Int, width: Int, height: Int
        let phase: Double
    }

    /// Painted at the scene's `pixelScale`, transparent around the sprites.
    let sheet: PixelBuffer
    let sprites: [Sprite]
}
