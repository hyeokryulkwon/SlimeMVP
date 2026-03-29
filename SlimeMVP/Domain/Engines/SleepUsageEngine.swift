import Foundation

enum SleepUsageEngine {
    static let minCandidateGapMin = 180
    static let microAwakeIgnoreMin = 10
    static let fallbackSleepPoint = 6.0

    static func compute(for day: Date, sessions: [UsageSession]) -> SleepComputation {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: day)
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) else {
            return fallback(day: dayStart)
        }

        let sorted = sessions
            .map { clip($0, to: dayStart..<dayEnd) }
            .filter { $0.start < $0.end }
            .sorted { $0.start < $1.start }

        if sorted.isEmpty {
            return fallback(day: dayStart)
        }

        var idleCandidates: [TimeSegment] = []
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i]
            let b = sorted[i + 1]
            if b.start <= a.end { continue }
            let gapMin = Int(b.start.timeIntervalSince(a.end) / 60)
            if gapMin >= minCandidateGapMin {
                idleCandidates.append(TimeSegment(start: a.end, end: b.start))
            }
        }

        if idleCandidates.isEmpty {
            return fallback(day: dayStart)
        }

        var merged: [TimeSegment] = []
        var idx = 0
        while idx < idleCandidates.count {
            var current = idleCandidates[idx]
            var j = idx

            while j + 1 < idleCandidates.count {
                let leftEnd = current.end
                let rightStart = idleCandidates[j + 1].start
                guard let bridge = sorted.first(where: { $0.start >= leftEnd && $0.end <= rightStart }) else { break }
                if bridge.durationMin <= microAwakeIgnoreMin {
                    current = TimeSegment(start: current.start, end: idleCandidates[j + 1].end)
                    j += 1
                } else {
                    break
                }
            }

            merged.append(current)
            idx = j + 1
        }

        guard let best = merged.max(by: { segmentMinutes($0) < segmentMinutes($1) }) else {
            return fallback(day: dayStart)
        }

        let minutes = segmentMinutes(best)
        let sleepHours = Double(minutes) / 60.0
        let rawPoint = 10.0 + 2.0 * (sleepHours - 8.0)
        let point = min(20.0, max(0.0, rawPoint))
        let category: SleepCategory = point < 8 ? .low : (point <= 12 ? .normal : .high)

        return SleepComputation(
            idleCandidates: idleCandidates,
            mergedSegments: merged,
            sleepMinutes: minutes,
            sleepPoint: point,
            category: category,
            usedFallback: false
        )
    }

    private static func fallback(day: Date) -> SleepComputation {
        SleepComputation(
            idleCandidates: [],
            mergedSegments: [],
            sleepMinutes: 360,
            sleepPoint: fallbackSleepPoint,
            category: .low,
            usedFallback: true
        )
    }

    private static func segmentMinutes(_ segment: TimeSegment) -> Int {
        max(0, Int(segment.end.timeIntervalSince(segment.start) / 60.0))
    }

    private static func clip(_ session: UsageSession, to range: Range<Date>) -> UsageSession {
        let start = max(session.start, range.lowerBound)
        let end = min(session.end, range.upperBound)
        return UsageSession(start: start, end: end)
    }
}
