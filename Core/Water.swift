/// The water over a scene's backdrop. The scene says where the water can't move and where it was disturbed;
/// the renderer simulates the waves on the GPU and bends, lights and reflects the floor with them.
final class WaterSurface {
    struct Disc {
        let center: Point
        let radius: Double
    }

    struct Drop {
        let disc: Disc
        let strength: Double
    }

    /// Where the water can't move, e.g. under lily pads; waves bounce off them and off the edges.
    let obstacles: [Disc]
    /// How deep the floor lies under a point, in design units: it sets how far the waves shift the floor
    /// and where the light and shadow they cast land on it.
    let depth: (Point) -> Double
    /// The colour the water turns the floor towards, the more of it the light passes through.
    var color = Color(0x236a62)
    private var drops: [Drop] = []

    /// Most disturbances one frame carries to the GPU.
    static let maxDropsPerFrame = 64
    /// The colour of the light on the floor and on the waves.
    static let light = Color(0xeafff5)

    init(obstacles: [Disc], depth: @escaping (Point) -> Double) {
        self.obstacles = obstacles
        self.depth = depth
    }

    /// Pushes the water down around `center`; `strength` 1 is a fingertip.
    func drop(at center: Point, radius: Double, strength: Double) {
        guard drops.count < Self.maxDropsPerFrame else { return }
        drops.append(Drop(disc: Disc(center: center, radius: radius), strength: strength))
    }

    /// The disturbances since the last call.
    func takeDrops() -> [Drop] {
        defer { drops.removeAll(keepingCapacity: true) }
        return drops
    }
}
