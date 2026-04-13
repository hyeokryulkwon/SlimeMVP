import Foundation

enum WeightEngine {
    static let baselineMoveKcal: Double = 400
    static let baselineSteps: Double = 5000

    static func compute(moveKcal: Double, steps: Double) -> (WeightCategory, diffPct: Double) {
        let moveScore = min(2.0, max(0, moveKcal / baselineMoveKcal))
        let stepScore = min(2.0, max(0, steps / baselineSteps))
        let dominantScore = max(moveScore, stepScore)
        let supportScore = min(moveScore, stepScore)
        // Favor balanced activity: one strong signal alone should not look "normal".
        let activityIndex = dominantScore * 0.35 + supportScore * 0.65
        let diffPct = 1.0 - activityIndex

        if activityIndex < 0.45 { return (.obese, diffPct) }
        if activityIndex < 0.75 { return (.overweight, diffPct) }
        if activityIndex <= 1.15 { return (.normal, diffPct) }
        if activityIndex <= 1.45 { return (.lean, diffPct) }
        return (.veryLean, diffPct)
    }
}
