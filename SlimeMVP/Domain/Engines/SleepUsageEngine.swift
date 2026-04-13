import Foundation

enum SleepUsageEngine {
    static let fallbackSleepPoint = 6.0
    static let lowSleepMinutes = 300
    static let highSleepMinutes = 480

    static func compute(sleepMinutes: Int) -> SleepComputation {
        guard sleepMinutes > 0 else {
            return fallback()
        }

        let sleepHours = Double(sleepMinutes) / 60.0
        let rawPoint = 10.0 + 2.0 * (sleepHours - 7.5)
        let point = min(20.0, max(0.0, rawPoint))
        let category: SleepCategory
        if sleepMinutes < lowSleepMinutes {
            category = .low
        } else if sleepMinutes <= highSleepMinutes {
            category = .normal
        } else {
            category = .high
        }

        return SleepComputation(
            sleepMinutes: sleepMinutes,
            sleepPoint: point,
            category: category,
            usedFallback: false
        )
    }

    private static func fallback() -> SleepComputation {
        SleepComputation(
            sleepMinutes: 0,
            sleepPoint: fallbackSleepPoint,
            category: .low,
            usedFallback: true
        )
    }

}
