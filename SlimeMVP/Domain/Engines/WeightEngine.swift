import Foundation

enum WeightEngine {
    static let intakeKcal: Double = 1800
    static let baseBMR: Double = 1500

    static func compute(moveKcal: Double, exerciseMin: Double) -> (WeightCategory, diffPct: Double) {
        let moveScore = min(2.0, max(0, moveKcal / 500.0))
        let exerciseScore = min(2.0, max(0, exerciseMin / 30.0))
        let activityScore = (moveScore + exerciseScore) / 2.0
        let adjustedBMR = baseBMR * (0.9 + activityScore * 0.1)
        let totalBurn = adjustedBMR + moveKcal + exerciseMin * 5.0
        let diffPct = (intakeKcal - totalBurn) / intakeKcal

        if diffPct >= 0.2 { return (.obese, diffPct) }
        if diffPct >= 0.1 { return (.overweight, diffPct) }
        if diffPct > -0.1 { return (.normal, diffPct) }
        if diffPct > -0.2 { return (.lean, diffPct) }
        return (.veryLean, diffPct)
    }
}
