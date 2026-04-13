import Foundation

enum DataSourceMode: String, CaseIterable, Identifiable, Codable {
    case real
    case mock

    var id: String { rawValue }
}

enum PermissionState: String, Codable {
    case granted
    case denied
    case unknown
}

enum Stage: Int, Codable {
    case stage0 = 0
    case stage1 = 1
    case stage2 = 2
    case stage3 = 3
}

enum WeightCategory: Int, Codable {
    case veryLean = -2
    case lean = -1
    case normal = 0
    case overweight = 1
    case obese = 2
}

enum SleepCategory: Int, Codable {
    case low = -1
    case normal = 0
    case high = 1
}

enum HappinessCategory: Int, Codable {
    case low = -1
    case normal = 0
    case high = 1
}

struct CompletenessFlags {
    var moveKcal: Bool
    var steps: Bool
    var sleep: Bool
    var playCount: Bool
    var petCount: Bool
}

struct DailyState {
    var date: Date
    var moveKcal: Double
    var steps: Double
    var playCount: Int
    var petCount: Int
    var dataSource: DataSourceMode
    var completeness: CompletenessFlags
}

struct SleepComputation {
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

struct EvolutionLogEntry: Identifiable, Codable {
    var id: UUID
    var evolvedAt: Date
    var dataSource: DataSourceMode
    var fromCharacterId: String
    var fromStage: Stage
    var toCharacterId: String
    var toStage: Stage
    var requiredMinutes: Int
    var elapsedMinutesAtCheck: Int
    var moveKcal: Double
    var steps: Double
    var sleepMinutes: Int
    var playCount: Int
    var petCount: Int
    var weight: WeightCategory
    var sleep: SleepCategory
    var happiness: HappinessCategory
    var reason: String
}

struct CharacterState: Codable {
    var characterId: String
    var stage: Stage
    var parentId: String?
    var enteredAt: Date
    var elapsedMinutes: Int
    var totalElapsedMinutes: Int
    var lastTickAt: Date
}

struct PersistenceSnapshot: Codable {
    var mode: DataSourceMode
    var permission: PermissionState
    var playCount: Int
    var petCount: Int
    var speedMultiplier: Int
    var mockMoveKcal: Double
    var mockSteps: Double
    var mockSleepMinutes: Int
    var currentCharacter: CharacterState
    var evolutionLogs: [EvolutionLogEntry]
}

struct EvolutionResult {
    var next: CharacterState
    var reason: String
}

struct PipelineTrace {
    var sleep: SleepComputation
    var weightActivityGap: Double
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

    static let imageNames: [String: String] = [
        "SL-01-01": "slime_sl_01_01",
        "SL-02-01": "slime_sl_02_01",
        "SL-02-02": "slime_sl_02_02",
        "SL-02-03": "slime_sl_02_03",
        "SL-03-01": "slime_sl_03_01",
        "SL-03-02": "slime_sl_03_02",
        "SL-03-03": "slime_sl_03_03",
        "SL-03-04": "slime_sl_03_04",
        "SL-03-05": "slime_sl_03_05",
        "SL-03-07": "slime_sl_03_07"
    ]

    static func imageName(for characterId: String) -> String? {
        imageNames[characterId]
    }
}
