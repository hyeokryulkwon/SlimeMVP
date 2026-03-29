import Foundation

enum HappinessEngine {
    static func compute(playCount: Int, petCount: Int) -> (HappinessCategory, point: Int) {
        let point = max(0, playCount + petCount)
        if point <= 1 { return (.low, point) }
        if point <= 4 { return (.normal, point) }
        return (.high, point)
    }
}
