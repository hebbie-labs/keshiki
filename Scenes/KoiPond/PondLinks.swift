import CoreGraphics
import Foundation

/// Where a pond opens into the pond on the next display: an edge, and the stretch of it (in the pond's own design
/// units) that the two displays share.
struct Opening {
    enum Edge { case left, right, top, bottom }

    let edge: Edge
    let span: ClosedRange<Double>
    /// How many koi the neighbouring pond has right now.
    let neighbourKoi: () -> Int
}

/// The ponds of all displays as one: each display's pond sits where its display does, and where two displays share
/// an edge the ponds open into each other. Koi and schools swim through, diving under at the opening and coming up
/// on the other side; the goose and the ball float over. A click calls the koi of the neighbours too.
final class PondLinks {
    private struct Member {
        let world: PondWorld
        /// The pond's top-left corner and its size, in shared design units (y down).
        let origin: Point
        let scale: Point

        func shared(_ point: Point) -> Point {
            Point(x: origin.x + point.x * scale.x, y: origin.y + point.y * scale.y)
        }

        func local(_ point: Point) -> Point {
            Point(x: (point.x - origin.x) / scale.x, y: (point.y - origin.y) / scale.y)
        }
    }

    private let members: [Member]
    /// Displays that touch closer than this many points share an edge.
    private static let touching: CGFloat = 2

    /// `frames` are the displays' frames in screen points (y up); `unitsPerPoint` is the scenes' design units per point.
    init(_ ponds: [(world: PondWorld, frame: CGRect)], unitsPerPoint: Double) {
        let top = ponds.map(\.frame.maxY).max() ?? 0
        members = ponds.map { pond in
            Member(world: pond.world,
                   origin: Point(x: Double(pond.frame.minX) * unitsPerPoint, y: Double(top - pond.frame.maxY) * unitsPerPoint),
                   scale: Point(x: Double(pond.frame.width) * unitsPerPoint / pond.world.size.width,
                                y: Double(pond.frame.height) * unitsPerPoint / pond.world.size.height))
        }
        for (index, pond) in ponds.enumerated() {
            let world = pond.world
            world.openings = ponds.filter { $0.world !== world }.compactMap { other in
                Self.opening(from: pond.frame, to: other.frame, in: world.size) { [weak neighbour = other.world] in neighbour?.kois.count ?? .max }
            }
            world.onCall = { [unowned self] point in self.callNeighbours(of: index, to: point) }
        }
    }

    /// Hands over whatever swam out through an opening to the pond it swam into.
    func exchange() {
        for (index, member) in members.enumerated() {
            let world = member.world
            for koi in world.kois where !world.size.contains(koi.head, margin: 0) {
                guard let (to, offset) = destination(from: index, of: koi.head) else { continue }
                world.release(koi)
                koi.shift(by: offset)
                to.adopt(koi)
            }
            for school in world.schools where !world.size.contains(school.center, margin: 0) {
                guard let (to, offset) = destination(from: index, of: school.center) else { continue }
                world.release(school)
                school.shift(by: offset)
                to.adopt(school)
            }
            if let goose = world.goose, !world.size.contains(goose.position, margin: 0),
               let (to, offset) = destination(from: index, of: goose.position), to.goose == nil {
                world.release(goose)
                goose.shift(by: offset)
                to.adopt(goose)
            }
            if let ball = world.ball, !world.size.contains(ball.position, margin: 0),
               let (to, offset) = destination(from: index, of: ball.position) {
                // One ball per pond: with one over there already, this one bounces back.
                guard to.ball == nil else { ball.bounceBack(into: world.size); continue }
                world.release(ball)
                ball.shift(by: offset)
                to.adopt(ball)
            }
        }
    }

    /// The pond a point just outside pond `index` lies in, and how far its coordinates are from this one's.
    private func destination(from index: Int, of point: Point) -> (PondWorld, Point)? {
        let from = members[index], shared = from.shared(point)
        for (other, member) in members.enumerated() where other != index {
            let local = member.local(shared)
            guard member.world.size.contains(local, margin: 60) else { continue }
            return (member.world, Point(x: local.x - point.x, y: local.y - point.y))
        }
        return nil
    }

    private func callNeighbours(of index: Int, to point: Point) {
        let shared = members[index].shared(point)
        for (other, member) in members.enumerated() where other != index {
            let local = member.local(shared)
            member.world.kois.forEach { $0.call(to: local) }
        }
    }

    /// The stretch of `frame`'s edge that `neighbour` touches, in the pond's units (frames are y up, ponds y down).
    private static func opening(from frame: CGRect, to neighbour: CGRect, in size: SceneSize, koi: @escaping () -> Int) -> Opening? {
        func along(_ low: CGFloat, _ high: CGFloat, over start: CGFloat, _ length: CGFloat, units: Double, flipped: Bool) -> ClosedRange<Double>? {
            guard high - low > 1 else { return nil }
            var a = Double((low - start) / length) * units, b = Double((high - start) / length) * units
            if flipped { (a, b) = (units - b, units - a) }
            return a...b
        }
        let rows = (max(frame.minY, neighbour.minY), min(frame.maxY, neighbour.maxY))
        let columns = (max(frame.minX, neighbour.minX), min(frame.maxX, neighbour.maxX))
        if abs(frame.maxX - neighbour.minX) < touching, let span = along(rows.0, rows.1, over: frame.minY, frame.height, units: size.height, flipped: true) {
            return Opening(edge: .right, span: span, neighbourKoi: koi)
        }
        if abs(frame.minX - neighbour.maxX) < touching, let span = along(rows.0, rows.1, over: frame.minY, frame.height, units: size.height, flipped: true) {
            return Opening(edge: .left, span: span, neighbourKoi: koi)
        }
        if abs(frame.maxY - neighbour.minY) < touching, let span = along(columns.0, columns.1, over: frame.minX, frame.width, units: size.width, flipped: false) {
            return Opening(edge: .top, span: span, neighbourKoi: koi)
        }
        if abs(frame.minY - neighbour.maxY) < touching, let span = along(columns.0, columns.1, over: frame.minX, frame.width, units: size.width, flipped: false) {
            return Opening(edge: .bottom, span: span, neighbourKoi: koi)
        }
        return nil
    }
}

extension PondWorld {
    /// How far past the edge something may go where the pond opens to a neighbour.
    static let openingDepth = 40.0
    /// Fish fade out over this distance before an opening, as if diving under.
    private static let diveDistance = 45.0

    /// `point` kept inside the pond by `margin`, except where an opening lets it through.
    func clamped(_ point: Point, margin: Double) -> Point {
        var kept = size.clamped(point, margin: margin)
        for opening in openings {
            switch opening.edge {
            case .left where opening.span.contains(point.y): kept.x = max(point.x, -Self.openingDepth)
            case .right where opening.span.contains(point.y): kept.x = min(point.x, size.width + Self.openingDepth)
            case .top where opening.span.contains(point.x): kept.y = max(point.y, -Self.openingDepth)
            case .bottom where opening.span.contains(point.x): kept.y = min(point.y, size.height + Self.openingDepth)
            default: continue
            }
        }
        return kept
    }

    /// A spot just past an opening, for fish that feel like swimming over; nil if there's no neighbour.
    /// Koi only go where there are no more koi than here, so the displays stay about even.
    func spotBeyondOpening(forKoi: Bool = false) -> Point? {
        let open = openings.filter { $0.span.upperBound - $0.span.lowerBound > 60 && (!forKoi || $0.neighbourKoi() <= kois.count) }
        guard let opening = open.randomElement() else { return nil }
        let along = random((opening.span.lowerBound + 30)...(opening.span.upperBound - 30)), past = Self.openingDepth
        switch opening.edge {
        case .left: return Point(x: -past, y: along)
        case .right: return Point(x: size.width + past, y: along)
        case .top: return Point(x: along, y: -past)
        case .bottom: return Point(x: along, y: size.height + past)
        }
    }

    /// 1 in open water, fading to 0 right at an opening: a fish heading through dives under first.
    func visibility(at point: Point) -> Double {
        var visible = 1.0
        for opening in openings {
            let distance: Double
            switch opening.edge {
            case .left where opening.span.contains(point.y): distance = point.x
            case .right where opening.span.contains(point.y): distance = size.width - point.x
            case .top where opening.span.contains(point.x): distance = point.y
            case .bottom where opening.span.contains(point.x): distance = size.height - point.y
            default: continue
            }
            visible = min(visible, clamp(distance / Self.diveDistance, 0, 1))
        }
        return visible
    }
}
