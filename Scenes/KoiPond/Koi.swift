import Foundation

enum KoiMood {
    case calm, playful

    init(_ name: String) {
        self = name == "playful" ? .playful : .calm
    }

    var speed: Double { self == .playful ? 1.45 : 0.75 }
    var turn: Double { self == .playful ? 1.5 : 1 }
    var wanderSeconds: ClosedRange<Double> { self == .playful ? 2...5 : 6...14 }
}

/// Where a koi is heading. Moving favourites carry `track`, so the koi keeps following them.
struct KoiTarget {
    var point: Point
    var isFavourite = false
    var track: (() -> Point?)?
}

final class Koi {
    struct Variety {
        let base: Color
        let patches: [Color]
        var crown: Color?
    }

    private struct Patch {
        let color: Color
        let side: Double
    }

    static let varieties = [
        Variety(base: Color(0xf3efe6), patches: [Color(0xc8322a), Color(0xd8442c)]),                // kohaku
        Variety(base: Color(0xf3efe6), patches: [Color(0xc8322a), Color(0x232323)]),                // sanke
        Variety(base: Color(0xd7c4a0), patches: [Color(0xe8902e), Color(0x9a8a70)]),                // ochiba
        Variety(base: Color(0xf2cf62), patches: [Color(0xfbe7a0)]),                                 // yamabuki
        Variety(base: Color(0x262626), patches: [Color(0xc8322a), Color(0xf3efe6)]),                // showa
        Variety(base: Color(0xeceae2), patches: [Color(0xffffff)]),                                 // platinum
        Variety(base: Color(0xf3efe6), patches: [], crown: Color(0xc8322a)),                        // tancho
        Variety(base: Color(0xa9652c), patches: [Color(0xc98a4a)]),                                 // chagoi
    ]

    private static let segments = 12
    private static let segmentLength = 5.5
    private static let bodyWidths = [5.0, 7.0, 7.9, 8.0, 7.5, 6.6, 5.4, 4.1, 3.0, 2.2, 1.6, 1.2]
    private static let foodSight = 420.0
    private static let callRadius = 380.0
    private static let gooseFearRadius = 90.0
    private static let personalSpace = 18.0
    /// How often a wandering koi heads over to the pond on a neighbouring display.
    private static let visitChance = 0.08
    private static let heartSeconds = 2.2
    /// How often a swimming koi stirs the surface above its back, and how fast it must swim for that.
    private static let wakeSeconds = 0.3
    private static let wakeSpeed = 0.5
    /// How much of its last sideways motion each body segment keeps, and how hard the body pulls itself straight.
    private static let inertia = 0.55
    private static let stiffness = 0.12
    private static let outline = Color(0x123a30, alpha: 0.18)
    /// How far towards the water's colour a koi turns at the bottom: deeper koi lose contrast and colour.
    private static let deepestMurk = 0.55
    /// How much smaller a koi looks at the bottom than just under the surface.
    private static let deepestShrink = 0.18
    /// The shadow on the floor: which way the light throws it, and how far for a koi just under the surface and
    /// one down at the floor. The higher above the floor, the further off, the larger and the fainter it lies.
    private static let shadowDirection = Point(x: -0.27, y: 0.96)
    private static let shadowReach: ClosedRange<Double> = 3...22
    private static let shadow = Color(0x0b2420)
    /// How fast a koi sinks or rises, in depth (0 just under the surface, 1 near the floor) per second.
    private static let diveRate = 0.12
    private static let fin = Color(0xf6efe4, alpha: 0.7)
    /// What the flanks turn towards as the round body curves away from the light.
    private static let flank = Color(0x1e2a30)
    /// Where the light comes from on screen (the far side of the pond, a little to the left): the body is lit
    /// on that side and its highlights sit there.
    private static let light = Point(x: -0.2, y: -0.98)
    /// Steps from the dark flanks to the lit back.
    private static let shadingLevels = 4
    /// The fine rays through a fin, a little darker than the fin.
    private static let finRay = Color(0xc9bfae, alpha: 0.5)

    let favourite: Favourite
    private(set) var body: [Point]
    private var previousBody: [Point]
    /// Leaning into the turn, -1...1: positive while turning clockwise on screen.
    private var roll = 0.0
    private(set) var heading = 0.0
    private(set) var velocity = 0.0
    private let variety: Variety
    private let patches: [Patch?]
    private let size = random(0.8...1.15)
    private let speed = random(0.9...1.15)
    private let turnRate = random(0.035...0.06)
    private var target: KoiTarget?
    private var wanderTimer = 0.0
    private var tailPhase = random(0...6.28)
    private var excitement = 0.0
    private var heartTimer = 0.0
    private var heartCooldown = random(5...20)
    private var wakeIn = random(0...0.3)
    /// 0 just under the surface, 1 down near the floor. Koi drift between depths while they wander and come up
    /// for food or when called.
    private(set) var depth = random(0...1)
    private var depthGoal = random(0...1)

    var head: Point { body[0] }

    init(index: Int, in pond: SceneSize) {
        variety = Self.varieties[index % Self.varieties.count]
        favourite = Favourite.allCases[index % Favourite.allCases.count]
        patches = Self.paintPatches(for: variety)
        let start = pond.randomPoint(marginX: 120, marginY: 80)
        body = (0..<Self.segments).map { Point(x: start.x - Double($0) * Self.segmentLength, y: start.y) }
        previousBody = body
    }

    func update(in world: PondWorld, dt: Double) {
        chooseTarget(in: world, dt: dt)
        swim(towards: steeringPoint(in: world), in: world, mood: KoiMood(world.options.mood), dt: dt)
        interact(with: world)
        followHead()
        stirWater(in: world, dt: dt)
        depth += clamp(depthGoal - depth, -Self.diveRate * dt, Self.diveRate * dt)
        heartTimer = max(0, heartTimer - dt)
        heartCooldown -= dt
    }

    /// A click on the water: nearby koi come over to see.
    func call(to point: Point) {
        guard head.distance(to: point) < Self.callRadius else { return }
        target = KoiTarget(point: point.jittered(15))
        depthGoal = 0
        wanderTimer = random(3...6)
        excitement = 0.6
    }

    func lookAround() {
        wanderTimer = 0
    }

    /// Moves the whole koi, e.g. into the coordinates of the pond it swam over to.
    func shift(by offset: Point) {
        for index in body.indices {
            body[index] = Point(x: body[index].x + offset.x, y: body[index].y + offset.y)
            previousBody[index] = Point(x: previousBody[index].x + offset.x, y: previousBody[index].y + offset.y)
        }
        target = nil
    }

    // MARK: - Behaviour

    private func chooseTarget(in world: PondWorld, dt: Double) {
        wanderTimer -= dt
        excitement = max(0, excitement - dt * 0.2)
        if let food = world.nearestFood(to: head, within: Self.foodSight) {
            target = KoiTarget(point: food)
            depthGoal = 0
            excitement = 1
        } else if let spot = world.greetingSpot {
            guard wanderTimer <= 0 else { return }
            target = KoiTarget(point: spot.jittered(35, 25))
            wanderTimer = random(2...4)
        } else if target == nil || wanderTimer <= 0 || target!.point.distance(to: head) < 10 {
            target = wanderTarget(in: world)
            depthGoal = chance(0.3) ? random(0...0.25) : random(0.3...1)
            wanderTimer = random(KoiMood(world.options.mood).wanderSeconds)
        } else if let position = target?.track?() {
            target?.point = position
        }
    }

    private func wanderTarget(in world: PondWorld) -> KoiTarget {
        if let spot = world.usualSpot, chance(0.6) { return KoiTarget(point: spot.jittered(40, 30)) }
        if KoiMood(world.options.mood) == .playful, let ball = world.ball, chance(0.3) { return KoiTarget(point: ball.position) }
        if chance(Self.visitChance), let beyond = world.spotBeyondOpening(forKoi: true) { return KoiTarget(point: beyond) }
        if chance(0.55), let favourite = world.target(for: favourite) { return favourite }
        return KoiTarget(point: world.size.randomPoint(marginX: 40))
    }

    /// The target, adjusted for fear of the goose and a little personal space.
    private func steeringPoint(in world: PondWorld) -> Point {
        if let goose = world.goose, favourite != .goose, goose.position.distance(to: head) < Self.gooseFearRadius {
            excitement = 0.8
            return Point(x: head.x + (head.x - goose.position.x) * 2, y: head.y + (head.y - goose.position.y) * 2)
        }
        var point = world.clamped(target?.point ?? head, margin: 25)
        for other in world.kois where other !== self && other.head.distance(to: head) < Self.personalSpace {
            point.x += head.x - other.head.x
            point.y += head.y - other.head.y
        }
        return point
    }

    private func swim(towards point: Point, in world: PondWorld, mood: KoiMood, dt: Double) {
        let maxTurn = turnRate * mood.turn
        let turn = clamp(angleDifference(from: heading, to: head.heading(to: point)), -maxTurn, maxTurn) * (1 + excitement) * dt * 60
        heading += turn
        roll += (clamp(turn / max(dt, 0.001) * 0.4, -1, 1) - roll) * 0.08
        let slowDownNearTarget = min(1, point.distance(to: head) / 60 + 0.25)
        let topSpeed = speed * mood.speed * (1 + excitement * 1.4) * slowDownNearTarget
        velocity += (topSpeed - velocity) * 0.04
        tailPhase += dt * (3 + velocity * 4)
        body[0] = world.clamped(head.moved(by: velocity * dt * 60, heading: heading), margin: 5)
    }

    private func interact(with world: PondWorld) {
        world.eatFood(near: head, reach: 7 * size)
        let grazed = world.grazeDuckweed(near: head, reach: 6 * size)
        let playedWithBall = world.ball?.nudge(by: self) ?? false
        let atFavourite = target?.isFavourite == true && target!.point.distance(to: head) < 30
        if atFavourite || (grazed && favourite == .duckweed) || (playedWithBall && favourite == .ball) { feelHappy() }
    }

    /// A koi just under the surface pushes the water up and aside; the faster, the more.
    private func stirWater(in world: PondWorld, dt: Double) {
        wakeIn -= dt
        guard wakeIn <= 0 else { return }
        wakeIn = Self.wakeSeconds
        guard velocity > Self.wakeSpeed, depth < 0.35 else { return }
        world.addRipple(at: body[2], radius: 2 * size, strength: 0.06 * velocity * size)
    }

    private func feelHappy() {
        guard heartCooldown <= 0 else { return }
        heartTimer = Self.heartSeconds
        heartCooldown = random(18...40)
    }

    /// The body is a chain of points with inertia (Verlet): each segment keeps some of its own sideways motion,
    /// stays one segment behind its leader and straightens a little, so the tail swings out in a turn and settles
    /// behind. Only sideways: carried forward, the segments would push into the ones ahead and buckle the body.
    private func followHead() {
        let length = Self.segmentLength * size
        for index in 1..<Self.segments {
            let current = body[index], leader = body[index - 1]
            let axisLength = max(current.distance(to: leader), 0.001)
            let axis = Point(x: (leader.x - current.x) / axisLength, y: (leader.y - current.y) / axisLength)
            let motion = Point(x: current.x - previousBody[index].x, y: current.y - previousBody[index].y)
            let along = motion.x * axis.x + motion.y * axis.y
            body[index].x += (motion.x - axis.x * along) * Self.inertia
            body[index].y += (motion.y - axis.y * along) * Self.inertia
            previousBody[index] = current
        }
        for index in 1..<Self.segments {
            if index >= 2 {
                let straight = Point(x: body[index - 1].x * 2 - body[index - 2].x, y: body[index - 1].y * 2 - body[index - 2].y)
                body[index].x += (straight.x - body[index].x) * Self.stiffness
                body[index].y += (straight.y - body[index].y) * Self.stiffness
            }
            let leader = body[index - 1]
            var dx = body[index].x - leader.x, dy = body[index].y - leader.y
            if dx == 0 && dy == 0 { dx = -cos(heading); dy = -sin(heading) }
            let gap = hypot(dx, dy)
            body[index] = Point(x: leader.x + dx / gap * length, y: leader.y + dy / gap * length)
        }
    }

    /// Three round spots along the back with the base colour between them, the way a kohaku's red sits on the white.
    private static func paintPatches(for variety: Variety) -> [Patch?] {
        var patches = [Patch?](repeating: nil, count: segments)
        guard !variety.patches.isEmpty else { return patches }
        var index = Int.random(in: 1...2)
        while index < 9 {
            patches[index] = Patch(color: variety.patches.randomElement()!, side: random(-0.2...0.2))
            index += 3
        }
        return patches
    }

    // MARK: - Drawing

    private struct Segment {
        let point: Point
        let direction: Double
    }

    private var outline: [Segment] = []

    /// The koi's shadow on the floor, drawn before any koi so it lies beneath them all: many faint discs two units
    /// apart along the body, which add up to a dark middle and a soft, blurred edge.
    func drawShadow(on canvas: Canvas, visibility: Double = 1) {
        guard visibility > 0 else { return }
        updateOutline()
        let height = 1 - depth
        let reach = Self.shadowReach.lowerBound + (Self.shadowReach.upperBound - Self.shadowReach.lowerBound) * height
        let color = Self.shadow.opacity((0.08 + 0.07 * depth) * visibility)
        for index in 0..<Self.segments - 1 {
            let from = outline[index].point, to = outline[index + 1].point
            let steps = max(1, Int((from.distance(to: to) / 2).rounded()))
            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                let width = Self.bodyWidths[index] + (Self.bodyWidths[index + 1] - Self.bodyWidths[index]) * t
                let spot = Point(x: from.x + (to.x - from.x) * t + Self.shadowDirection.x * reach,
                                 y: from.y + (to.y - from.y) * t + Self.shadowDirection.y * reach)
                canvas.disc(spot, radius: width * looks * (1 + 0.35 * height), color)
            }
        }
    }

    /// `visibility` below 1 while it dives under at an opening to the next pond. `murk` is the water's colour,
    /// which a deep koi turns towards.
    func draw(on canvas: Canvas, murk: Color, visibility: Double = 1) {
        guard visibility > 0 else { return }
        var canvas = visibility < 1 ? FadedCanvas(canvas, amount: visibility) : canvas
        if depth > 0.02 { canvas = ShadedCanvas(canvas, toward: murk, amount: depth * Self.deepestMurk) }
        updateOutline()
        drawFins(outline, on: canvas, color: Self.fin)
        drawBody(outline, on: canvas, color: Self.outline, widen: 1)
        // A round body: darker flanks, lit towards the light, a highlight along the back.
        // The thin tail is too narrow to shade; there it would break into beads.
        drawBody(outline, on: canvas, color: variety.base.mixed(with: Self.flank, 0.2))
        for level in 0..<Self.shadingLevels {
            let t = Double(level) / Double(Self.shadingLevels - 1)
            drawBody(outline, on: canvas, color: variety.base.mixed(with: Self.flank, 0.45 * pow(1 - t, 1.5)), width: 1 - 0.45 * t, shift: 0.2 * t, through: 8)
        }
        drawPatches(outline, on: canvas)
        drawDorsalFin(outline, on: canvas)
        drawFace(outline, on: canvas)
        if heartTimer > 0 {
            canvas.heart(Point(x: outline[0].point.x, y: outline[0].point.y - 18 - (Self.heartSeconds - heartTimer) * 6), opacity: min(1, heartTimer))
        }
    }

    /// Segment centres with the swimming wave applied sideways, plus each segment's direction.
    private func updateOutline() {
        outline.removeAll(keepingCapacity: true)
        for index in body.indices {
            let ahead = body[max(0, index - 1)], behind = body[min(Self.segments - 1, index + 1)]
            let direction = behind.heading(to: ahead)
            let sway = sin(tailPhase - Double(index) * 0.7) * (Double(index) / Double(Self.segments)) * 3 * size
            outline.append(Segment(point: body[index].moved(by: sway, heading: direction + .pi / 2), direction: direction))
        }
        // Deeper koi look smaller: drawn shrunk towards the middle of the body.
        let middle = outline[Self.segments / 2].point, shrink = 1 - depth * Self.deepestShrink
        for index in outline.indices {
            let point = outline[index].point
            outline[index] = Segment(point: Point(x: middle.x + (point.x - middle.x) * shrink, y: middle.y + (point.y - middle.y) * shrink),
                                     direction: outline[index].direction)
        }
    }

    /// The koi's size as drawn: smaller the deeper it swims.
    private var looks: Double { size * (1 - depth * Self.deepestShrink) }

    /// Fixed fins: they keep their shape and only follow the body. Two rounded pectoral fins behind the head, two
    /// small pelvic fins further back, a fan-shaped tail and the dorsal fin as a ridge along the back.
    private func drawFins(_ outline: [Segment], on canvas: Canvas, color: Color) {
        for side in [-1.0, 1.0] {
            drawFin(from: outline[2], angle: side * 1.95, length: 12, width: 3.2, on: canvas, color: color)
            drawFin(from: outline[6], angle: side * 2.3, length: 7, width: 1.8, on: canvas, color: color)
            drawFin(from: outline[Self.segments - 1], angle: .pi + side * 0.45, length: 10, width: 3.2, on: canvas, color: color)
        }
    }

    /// A fin as a paddle from its root on the body: narrow at the root, widest two thirds out, rounded at the tip,
    /// with a ray along the middle.
    private func drawFin(from root: Segment, angle: Double, length: Double, width: Double, on canvas: Canvas, color: Color) {
        let heading = root.direction + angle, reach = length * looks
        for step in stride(from: 0.0, through: reach, by: 0.8) {
            let t = step / reach
            let radius = width * looks * (0.35 + 0.65 * sin(min(t / 0.7, 1) * .pi / 2)) * (t > 0.7 ? sqrt(max(0, 1 - (t - 0.7) / 0.3 * 0.8)) : 1)
            canvas.disc(root.point.moved(by: step, heading: heading), radius: radius, color)
        }
        for step in stride(from: 1.0, to: reach * 0.85, by: 1.0) {
            canvas.disc(root.point.moved(by: step, heading: heading), radius: 0.3, Self.finRay)
        }
    }

    private func drawDorsalFin(_ outline: [Segment], on canvas: Canvas) {
        for index in 2...7 { canvas.disc(outline[index].point, radius: 0.7 * looks, Self.finRay) }
    }

    /// Discs per segment plus one between neighbours, so the thin tail doesn't look dotted. `width` is a share of
    /// the body's width, `shift` how far towards the light (as a share of the width), `through` the last segment.
    private func drawBody(_ outline: [Segment], on canvas: Canvas, color: Color, width: Double = 1, widen: Double = 0,
                          shift: Double = 0, through last: Int = segments - 1) {
        let lean = 1 - abs(roll) * 0.12
        func disc(at point: Point, radius: Double) {
            canvas.disc(Point(x: point.x + Self.light.x * radius * shift, y: point.y + Self.light.y * radius * shift),
                        radius: radius * width * lean + widen, color)
        }
        for index in stride(from: last, through: 0, by: -1) {
            disc(at: outline[index].point, radius: Self.bodyWidths[index] * looks)
            guard index < last else { continue }
            let next = outline[index + 1]
            disc(at: Point(x: (outline[index].point.x + next.point.x) / 2, y: (outline[index].point.y + next.point.y) / 2),
                 radius: (Self.bodyWidths[index] + Self.bodyWidths[index + 1]) / 2 * looks)
        }
    }

    private func drawPatches(_ outline: [Segment], on canvas: Canvas) {
        for index in stride(from: Self.segments - 1, through: 1, by: -1) {
            guard let patch = patches[index] else { continue }
            let width = Self.bodyWidths[index] * looks
            let center = outline[index].point.moved(by: patch.side * width * 0.5, heading: outline[index].direction + .pi / 2)
            let radius = max(width * 0.68, 2.5 * looks)
            // The spot curves with the body: darker at its rim, lit towards the light.
            for level in 0..<3 {
                let t = Double(level) / 2
                canvas.disc(Point(x: center.x + Self.light.x * radius * 0.15 * t, y: center.y + Self.light.y * radius * 0.15 * t),
                            radius: radius * (1 - 0.3 * t), patch.color.mixed(with: Self.flank, 0.3 * (1 - t)))
            }
        }
        if let crown = variety.crown { canvas.disc(outline[1].point, radius: 3 * looks, crown) }
    }

    private func drawFace(_ outline: [Segment], on canvas: Canvas) {
        // One round glint on the back, behind the head, towards the light: a soft halo around a bright core.
        let back = outline[2].point, offset = Self.bodyWidths[2] * looks * 0.3
        let glint = Point(x: back.x + Self.light.x * offset, y: back.y + Self.light.y * offset)
        canvas.disc(glint, radius: 2.2 * looks, Color(0xffffff, alpha: 0.12))
        canvas.disc(glint, radius: 1.2 * looks, Color(0xffffff, alpha: 0.3))
        for side in [-1.0, 1.0] { canvas.plot(outline[0].point.moved(by: 3.4 * looks, heading: heading + side * 1.2), Color(0x111111)) }
    }
}
