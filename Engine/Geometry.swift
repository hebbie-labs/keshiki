import Foundation

struct Point: Equatable {
    var x: Double
    var y: Double

    func distance(to other: Point) -> Double {
        hypot(x - other.x, y - other.y)
    }

    func moved(by length: Double, heading: Double) -> Point {
        Point(x: x + cos(heading) * length, y: y + sin(heading) * length)
    }

    func heading(to other: Point) -> Double {
        atan2(other.y - y, other.x - x)
    }

    func jittered(_ spreadX: Double, _ spreadY: Double? = nil) -> Point {
        let spreadY = spreadY ?? spreadX
        return Point(x: x + random(-spreadX...spreadX), y: y + random(-spreadY...spreadY))
    }
}

struct PondSize {
    let width: Double
    let height: Double

    var center: Point { Point(x: width / 2, y: height / 2) }

    func randomPoint(marginX: Double, marginY: Double? = nil) -> Point {
        let marginY = marginY ?? marginX
        return Point(x: random(marginX...(width - marginX)), y: random(marginY...(height - marginY)))
    }

    func clamped(_ point: Point, margin: Double) -> Point {
        Point(x: clamp(point.x, margin, width - margin), y: clamp(point.y, margin, height - margin))
    }

    func contains(_ point: Point, margin: Double) -> Bool {
        point.x >= -margin && point.x <= width + margin && point.y >= -margin && point.y <= height + margin
    }
}

func random(_ range: ClosedRange<Double>) -> Double {
    Double.random(in: range)
}

func chance(_ probability: Double) -> Bool {
    Double.random(in: 0..<1) < probability
}

func clamp<T: Comparable>(_ value: T, _ minimum: T, _ maximum: T) -> T {
    max(minimum, min(maximum, value))
}

/// Signed shortest turn from one angle to another, in -π...π.
func angleDifference(from: Double, to: Double) -> Double {
    var difference = (to - from).truncatingRemainder(dividingBy: 2 * .pi)
    if difference > .pi { difference -= 2 * .pi }
    if difference < -.pi { difference += 2 * .pi }
    return difference
}
