import Foundation
import HealthKit
import SwiftUI
import Combine

@MainActor
final class MVPViewModel: ObservableObject {
    static let defaultPlayCount = 2
    static let defaultPetCount = 1
    static let defaultSpeedMultiplier = 1
    static let defaultMockMoveKcal: Double = 400
    static let defaultMockSteps: Double = 5000
    static let defaultMockSleepMinutes = 420
    static let defaultHealthDebugSummary = "Mode: mock\nHealth fetch not run yet."
    static let defaultRuntimeDebugSummary = "Runtime: app active when open\nBackground: catch-up on next launch"

    @Published var mode: DataSourceMode = .mock { didSet { saveState() } }
    @Published var permission: PermissionState = .unknown { didSet { saveState() } }
    @Published var playCount: Int = defaultPlayCount { didSet { saveState() } }
    @Published var petCount: Int = defaultPetCount { didSet { saveState() } }
    @Published var speedMultiplier: Int = defaultSpeedMultiplier { didSet { saveState() } }
    @Published var mockMoveKcal: Double = defaultMockMoveKcal { didSet { saveState() } }
    @Published var mockSteps: Double = defaultMockSteps { didSet { saveState() } }
    @Published var mockSleepMinutes: Int = defaultMockSleepMinutes { didSet { saveState() } }

    @Published var currentCharacter = CharacterState(
        characterId: "SL-00-01",
        stage: .stage0,
        parentId: nil,
        enteredAt: Date(),
        elapsedMinutes: 0,
        totalElapsedMinutes: 0,
        lastTickAt: Date()
    ) { didSet { saveState() } }

    @Published var output: PipelineOutput?
    @Published var lastError: String?
    @Published var healthDebugSummary: String = defaultHealthDebugSummary
    @Published var runtimeDebugSummary: String = defaultRuntimeDebugSummary
    @Published var evolutionLogs: [EvolutionLogEntry] = [] { didSet { saveState() } }

    private let healthProvider = HealthKitActivityProvider()
    private let persistenceKey = "slime_mvp_persistence_v1"
    private var isRestoringState = false
    private var lastCatchUpMinutes = 0

    init() {
        restoreState()
        reconcileElapsedTimeIfNeeded()
        refreshRuntimeDebugSummary()
    }

    func requestHealthPermission() async {
        do {
            let granted = try await healthProvider.requestAuthorization()
            permission = granted ? .granted : .denied

            if granted {
                healthDebugSummary = [
                    "Mode: \(mode.rawValue)",
                    "Health Request: completed",
                    "Read Check: Run Pipeline으로 실제 조회 확인"
                ].joined(separator: "\n")
            } else {
                healthDebugSummary = [
                    "Mode: \(mode.rawValue)",
                    "Health Request: denied",
                    "Read Check: 조회 전 권한 확인 필요"
                ].joined(separator: "\n")
            }
        } catch {
            permission = .denied
            lastError = "Health 권한 요청 실패: \(error.localizedDescription)"
            healthDebugSummary = [
                "Mode: \(mode.rawValue)",
                "Health Request: failed",
                "Error: \(error.localizedDescription)"
            ].joined(separator: "\n")
            print("[ViewModel] requestHealthPermission error: \(error.localizedDescription)")
        }
    }

    func tick(minutes: Int) {
        let delta = max(0, minutes * max(1, speedMultiplier))
        currentCharacter.elapsedMinutes += delta
        currentCharacter.totalElapsedMinutes += delta
        currentCharacter.lastTickAt = Date()
    }

    func incrementPlayCount() {
        playCount += 1
    }

    func incrementPetCount() {
        petCount += 1
    }

    func adjustMockMoveKcal(by delta: Double) {
        mockMoveKcal = max(0, mockMoveKcal + delta)
    }

    func adjustMockSteps(by delta: Double) {
        mockSteps = max(0, mockSteps + delta)
    }

    func adjustMockSleepMinutes(by delta: Int) {
        mockSleepMinutes = max(0, mockSleepMinutes + delta)
    }

    func resetProgress() {
        isRestoringState = true
        mode = .mock
        permission = .unknown
        playCount = Self.defaultPlayCount
        petCount = Self.defaultPetCount
        speedMultiplier = Self.defaultSpeedMultiplier
        mockMoveKcal = Self.defaultMockMoveKcal
        mockSteps = Self.defaultMockSteps
        mockSleepMinutes = Self.defaultMockSleepMinutes
        currentCharacter = Self.makeInitialCharacter()
        output = nil
        lastError = nil
        healthDebugSummary = Self.defaultHealthDebugSummary
        runtimeDebugSummary = Self.defaultRuntimeDebugSummary
        evolutionLogs = []
        UserDefaults.standard.removeObject(forKey: persistenceKey)
        isRestoringState = false
        saveState()
    }

    func runPipeline() async {
        reconcileElapsedTimeIfNeeded()
        let now = Date()
        let activity: HealthKitActivityProvider.TodayActivity?
        switch mode {
        case .real:
            activity = await healthProvider.fetchTodayActivity()
        case .mock:
            activity = HealthKitActivityProvider.TodayActivity(
                moveKcal: mockMoveKcal,
                steps: mockSteps,
                sleepMinutes: mockSleepMinutes,
                moveQuerySucceeded: true,
                stepsQuerySucceeded: true,
                sleepQuerySucceeded: true,
                sleepSource: "mock"
            )
        }

        guard let activity else {
            lastError = "Health 데이터를 불러오지 못했습니다: nil 반환"
            healthDebugSummary = [
                "Mode: \(mode.rawValue)",
                "Health Fetch: failed",
                "판정: 데이터 조회 실패"
            ].joined(separator: "\n")
            print("[ViewModel] fetchTodayActivity returned nil")
            return
        }

        let completeness = CompletenessFlags(
            moveKcal: activity.moveKcal > 0,
            steps: activity.steps > 0,
            sleep: activity.sleepMinutes > 0,
            playCount: true,
            petCount: true
        )

        let daily = DailyState(
            date: now,
            moveKcal: activity.moveKcal,
            steps: activity.steps,
            playCount: max(0, playCount),
            petCount: max(0, petCount),
            dataSource: mode,
            completeness: completeness
        )

        print("[ViewModel] runPipeline - today moveKcal: \(activity.moveKcal), steps: \(activity.steps), sleepMinutes: \(activity.sleepMinutes)")
        healthDebugSummary = [
            "Mode: \(mode.rawValue)",
            "Move: \(Int(activity.moveKcal)) kcal (\(dataJudgment(value: activity.moveKcal, querySucceeded: activity.moveQuerySucceeded, mode: mode, zeroLabel: "현재 일자 0")))",
            "Steps: \(Int(activity.steps)) (\(dataJudgment(value: activity.steps, querySucceeded: activity.stepsQuerySucceeded, mode: mode, zeroLabel: "현재 일자 0")))",
            "Sleep: \(activity.sleepMinutes) min (\(dataJudgment(value: Double(activity.sleepMinutes), querySucceeded: activity.sleepQuerySucceeded, mode: mode, zeroLabel: "조회값 0")))",
            "Sleep Source: \(sleepSourceLabel(for: activity.sleepSource, mode: mode))",
            "Real Mode: \(realModeJudgment(mode: mode, activity: activity))"
        ].joined(separator: "\n")


        let (weight, diff) = WeightEngine.compute(moveKcal: daily.moveKcal, steps: daily.steps)
        let sleep = SleepUsageEngine.compute(sleepMinutes: activity.sleepMinutes)
        let (happiness, point) = HappinessEngine.compute(playCount: daily.playCount, petCount: daily.petCount)

        let snapshot = CategorySnapshot(weight: weight, sleep: sleep.category, happiness: happiness)

        var reason = "Stage 유지"
        while StageTimerEngine.canEvolve(currentCharacter) {
            let previous = currentCharacter
            let requiredMinutes = StageTimerEngine.requiredMinutes(for: previous.stage) ?? 0
            let elapsedMinutesAtCheck = previous.elapsedMinutes
            let overflow = max(0, elapsedMinutesAtCheck - requiredMinutes)
            let evolved = EvolutionEngine.evolve(current: currentCharacter, snapshot: snapshot, now: now)
            currentCharacter = evolved.next
            currentCharacter.elapsedMinutes = overflow
            currentCharacter.lastTickAt = now
            reason = evolved.reason
            appendEvolutionLog(
                from: previous,
                to: currentCharacter,
                requiredMinutes: requiredMinutes,
                elapsedMinutesAtCheck: elapsedMinutesAtCheck,
                daily: daily,
                sleepMinutes: activity.sleepMinutes,
                snapshot: snapshot,
                reason: evolved.reason,
                now: now
            )
            if currentCharacter.stage == .stage3 {
                break
            }
        }

        output = PipelineOutput(
            daily: daily,
            snapshot: snapshot,
            character: currentCharacter,
            trace: PipelineTrace(
                sleep: sleep,
                weightActivityGap: diff,
                happinessPoint: point,
                evolutionReason: reason
            )
        )
    }

    private func saveState() {
        guard !isRestoringState else { return }
        let snapshot = PersistenceSnapshot(
            mode: mode,
            permission: permission,
            playCount: playCount,
            petCount: petCount,
            speedMultiplier: speedMultiplier,
            mockMoveKcal: mockMoveKcal,
            mockSteps: mockSteps,
            mockSleepMinutes: mockSleepMinutes,
            currentCharacter: currentCharacter,
            evolutionLogs: evolutionLogs
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let snapshot = try? JSONDecoder().decode(PersistenceSnapshot.self, from: data) else {
            return
        }

        isRestoringState = true
        mode = snapshot.mode
        permission = snapshot.permission
        playCount = snapshot.playCount
        petCount = snapshot.petCount
        speedMultiplier = snapshot.speedMultiplier
        mockMoveKcal = snapshot.mockMoveKcal
        mockSteps = snapshot.mockSteps
        mockSleepMinutes = snapshot.mockSleepMinutes
        currentCharacter = snapshot.currentCharacter
        evolutionLogs = snapshot.evolutionLogs
        isRestoringState = false
        saveState()
    }

    func clearEvolutionLogs() {
        evolutionLogs = []
    }

    private func reconcileElapsedTimeIfNeeded(now: Date = Date()) {
        let deltaSeconds = now.timeIntervalSince(currentCharacter.lastTickAt)
        guard deltaSeconds > 0 else {
            refreshRuntimeDebugSummary()
            return
        }

        let deltaMinutes = Int(deltaSeconds / 60.0)
        guard deltaMinutes > 0 else {
            refreshRuntimeDebugSummary()
            return
        }

        currentCharacter.elapsedMinutes += deltaMinutes
        currentCharacter.totalElapsedMinutes += deltaMinutes
        currentCharacter.lastTickAt = now
        lastCatchUpMinutes = deltaMinutes
        refreshRuntimeDebugSummary(referenceDate: now)
    }

    private func refreshRuntimeDebugSummary(referenceDate: Date = Date()) {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        runtimeDebugSummary = [
            "Runtime: foreground when app is open",
            "Background: not continuously running",
            "Catch-up: applied on next launch/active",
            "Last Catch-up: \(lastCatchUpMinutes) min",
            "Last Sync: \(formatter.string(from: referenceDate))"
        ].joined(separator: "\n")
    }

    private static func makeInitialCharacter(now: Date = Date()) -> CharacterState {
        CharacterState(
            characterId: "SL-00-01",
            stage: .stage0,
            parentId: nil,
            enteredAt: now,
            elapsedMinutes: 0,
            totalElapsedMinutes: 0,
            lastTickAt: now
        )
    }

    private func dataJudgment(value: Double, querySucceeded: Bool, mode: DataSourceMode, zeroLabel: String) -> String {
        if mode == .mock {
            return "mock 데이터"
        }
        guard querySucceeded else {
            return permission == .unknown ? "권한 또는 조회 문제" : "조회 실패"
        }
        return value > 0 ? "정상" : zeroLabel
    }

    private func realModeJudgment(mode: DataSourceMode, activity: HealthKitActivityProvider.TodayActivity) -> String {
        if mode == .mock {
            return "mock 데이터 사용 중"
        }
        let succeededQueries = [
            activity.moveQuerySucceeded,
            activity.stepsQuerySucceeded,
            activity.sleepQuerySucceeded
        ]
        if succeededQueries.contains(false) {
            return "일부 항목 조회 실패"
        }
        if activity.moveKcal > 0 || activity.steps > 0 || activity.sleepMinutes > 0 {
            return "실데이터 반영 중"
        }
        return "조회는 성공, 현재 값은 0"
    }

    private func sleepSourceLabel(for source: String, mode: DataSourceMode) -> String {
        if mode == .mock {
            return "mock input"
        }
        switch source {
        case "asleep":
            return "asleep sample"
        case "inBed fallback":
            return "inBed fallback"
        case "no samples":
            return "sleep sample 없음"
        case "failed":
            return "조회 실패"
        default:
            return source
        }
    }

    private func appendEvolutionLog(
        from previous: CharacterState,
        to next: CharacterState,
        requiredMinutes: Int,
        elapsedMinutesAtCheck: Int,
        daily: DailyState,
        sleepMinutes: Int,
        snapshot: CategorySnapshot,
        reason: String,
        now: Date
    ) {
        let entry = EvolutionLogEntry(
            id: UUID(),
            evolvedAt: now,
            dataSource: daily.dataSource,
            fromCharacterId: previous.characterId,
            fromStage: previous.stage,
            toCharacterId: next.characterId,
            toStage: next.stage,
            requiredMinutes: requiredMinutes,
            elapsedMinutesAtCheck: elapsedMinutesAtCheck,
            moveKcal: daily.moveKcal,
            steps: daily.steps,
            sleepMinutes: sleepMinutes,
            playCount: daily.playCount,
            petCount: daily.petCount,
            weight: snapshot.weight,
            sleep: snapshot.sleep,
            happiness: snapshot.happiness,
            reason: reason
        )
        evolutionLogs.insert(entry, at: 0)
    }

    var remainingMinutes: Int {
        StageTimerEngine.remainingMinutes(currentCharacter)
    }
}
