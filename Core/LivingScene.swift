import CoreGraphics
import Foundation

/// A living wallpaper: something that moves on its own and can be drawn into a small pixel image.
protocol LivingScene: AnyObject {
    var settings: KeshikiSettings { get set }
    var systemDark: Bool { get set }

    func advance(by dt: Double)
    func render(at date: Date) -> CGImage?
    /// A click on the desktop; `spot` runs 0...1 across the display, origin top-left.
    func touch(at spot: Point, withOption: Bool)
}

extension LivingScene {
    func render() -> CGImage? {
        render(at: Date())
    }
}
