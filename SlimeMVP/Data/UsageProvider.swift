import Foundation

protocol UsageProvider {
    func fetchTodaySessions(mode: DataSourceMode) async -> [UsageSession]
}

final class DefaultUsageProvider: UsageProvider {
    func fetchTodaySessions(mode: DataSourceMode) async -> [UsageSession] {
        switch mode {
        case .real:
            // NOTE: iOS 정책상 Screen/Usage raw event 직접 접근이 제한될 수 있음.
            // MVP에서는 real 모드 시도 후 실패하면 빈 배열(=fallback)로 처리.
            return []
        case .mock:
            return UsageFixtures.defaultDay
        case .manual:
            return []
        }
    }
}

enum UsageFixtures {
    static var defaultDay: [UsageSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())

        func d(_ hour: Int, _ min: Int) -> Date {
            cal.date(bySettingHour: hour, minute: min, second: 0, of: start) ?? start
        }

        return [
            UsageSession(start: d(0, 10), end: d(0, 20)),
            UsageSession(start: d(7, 40), end: d(7, 47)),
            UsageSession(start: d(12, 10), end: d(12, 30)),
            UsageSession(start: d(18, 0), end: d(18, 20)),
            UsageSession(start: d(23, 20), end: d(23, 35))
        ]
    }
}
