import Foundation

enum DataSourceMode: String, CaseIterable, Identifiable {
    case real
    case mock
    case manual

    var id: String { rawValue }
}

enum PermissionState: String {
    case granted
    case denied
    case unknown
}

enum Stage: Int {
    case stage0 = 0
    case stage1 = 1
    case stage2 = 2
    case stage3 = 3
}

enum WeightCategory: Int {
    case veryLean = -2
    case lean = -1
    case normal = 0
    case overweight = 1
    case obese = 2
}

enum SleepCategory: Int {
    case low = -1
    case normal = 0
    case high = 1
}

enum HappinessCategory: Int {
    case low = -1
    case normal = 0
    case high = 1
}

struct CompletenessFlags {
    var moveKcal: Bool
    var exerciseMin: Bool
    var sleep: Bool
    var playCount: Bool
    var petCount: Bool
}

struct UsageSession: Identifiable {
    var id = UUID()
    var start: Date
    var end: Date
    var durationMin: Int {
        max(0, Int(end.timeIntervalSince(start) / 60.0))
    }
}

struct TimeSegment {
    var start: Date
    var end: Date
}

struct DailyState {
    var date: Date
    var moveKcal: Double
    var exerciseMin: Double
    var screenEvents: [UsageSession]
    var playCount: Int
    var petCount: Int
    var dataSource: DataSourceMode
    var completeness: CompletenessFlags
}

struct SleepComputation {
    var idleCandidates: [TimeSegment]
    var mergedSegments: [TimeSegment]
    var sleepMinutes: Int
    var sleepPoint: Double
    var category: SleepCategory
    var usedFallback: Bool
}

struct CategorySnapshot {
    var weight: WeightCategory
    var sleep: SleepCategory
    var happiness: HappinessCategory
}

struct CharacterState {
    var characterId: String
    var stage: Stage
    var parentId: String?
    var enteredAt: Date
    var elapsedMinutes: Int
    var lastTickAt: Date
}

struct EvolutionResult {
    var next: CharacterState
    var reason: String
}

struct PipelineTrace {
    var sleep: SleepComputation
    var weightDiffPct: Double
    var happinessPoint: Int
    var evolutionReason: String
}

struct PipelineOutput {
    var daily: DailyState
    var snapshot: CategorySnapshot
    var character: CharacterState
    var trace: PipelineTrace
}

enum CharacterCatalog {
    static let names: [String: String] = [
        "SL-00-01": "알",
        "SL-01-01": "태초의 슬라임",
        "SL-02-01": "시작의 슬라임",
        "SL-02-02": "포근 슬라임",
        "SL-02-03": "허기 슬라임",
        "SL-02-04": "틈새 슬라임",
        "SL-03-01": "뿔 슬라임",
        "SL-03-02": "몽롱 슬라임",
        "SL-03-03": "포동 슬라임",
        "SL-03-04": "단단 슬라임",
        "SL-03-05": "꽃잠 슬라임",
        "SL-03-06": "몽실 슬라임",
        "SL-03-07": "공허 슬라임",
        "SL-03-08": "경계 슬라임"
    ]
}
