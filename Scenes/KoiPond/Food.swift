import Foundation


struct FoodPellet {
    var position: Point
    var secondsLeft: Double
}

extension PondWorld {
    private static let pelletsPerDrop = 8
    private static let secondsAfloat = 30.0
    private static let pelletColor = Color(0xc98a3e)

    func dropFood(at point: Point) {
        addRipple(at: point)
        for _ in 0..<Self.pelletsPerDrop {
            food.append(FoodPellet(position: point.jittered(10, 8), secondsLeft: Self.secondsAfloat))
        }
    }

    func sinkOldFood(dt: Double) {
        for index in food.indices { food[index].secondsLeft -= dt }
        food.removeAll { $0.secondsLeft <= 0 }
    }

    func nearestFood(to point: Point, within range: Double) -> Point? {
        food.map(\.position).filter { $0.distance(to: point) < range }.min { $0.distance(to: point) < $1.distance(to: point) }
    }

    func eatFood(near point: Point, reach: Double) {
        guard let index = food.firstIndex(where: { $0.position.distance(to: point) < reach }) else { return }
        addRipple(at: food[index].position)
        food.remove(at: index)
    }

    func drawFood(on canvas: PixelBuffer) {
        for pellet in food { canvas.fillRect(pellet.position, width: 2, height: 2, Self.pelletColor) }
    }
}
