import Foundation

enum Favourite: CaseIterable {
    case tinyFish, duckweed, lotusShade, frog, ball, goose
}

extension PondWorld {
    /// Where a koi goes to enjoy its favourite thing, or nil if that thing isn't around.
    func target(for favourite: Favourite) -> KoiTarget? {
        switch favourite {
        case .tinyFish:
            return tracking { [unowned self] in herdedSchool.center }
        case .duckweed:
            return randomGrowingLeaf().map { KoiTarget(point: $0, isFavourite: true) }
        case .lotusShade:
            return pads.randomElement().map { KoiTarget(point: $0.center.jittered($0.radius * 0.6), isFavourite: true) }
        case .frog:
            let pad = pads[frog.padIndex]
            return KoiTarget(point: pad.center.moved(by: pad.radius + 10, heading: random(0...(2 * .pi))), isFavourite: true)
        case .ball:
            return ball == nil ? nil : tracking { [unowned self] in ball?.position }
        case .goose:
            return goose == nil ? nil : tracking { [unowned self] in goose?.spotBehind }
        }
    }

    private func tracking(_ locate: @escaping () -> Point?) -> KoiTarget? {
        locate().map { KoiTarget(point: $0, isFavourite: true, track: locate) }
    }
}
