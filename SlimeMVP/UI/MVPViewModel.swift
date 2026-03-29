import Foundation
import HealthKit
import SwiftUI
import Combine

@MainActor
final class MVPViewModel: ObservableObject {
    @Published var mode: DataSourceMode = .mock
    @Published var permission: PermissionState = .unknown
    @Published var playCount: Int = 2
    @Published var petCount: Int = 1
    @Published var manualSessions: [UsageSession] = []
    @Published var speedMultiplier: Int = 1

    @Published var currentCharacter = CharacterState(
        characterId: "SL-00-01",
        stage: .stage0,
        parentId: nil,
        enteredAt: Date(),
        elapsedMinutes: 0,
        lastTickAt: Date()
    )

    @Published var output: PipelineOutput?
    @Published var lastError: String?

    private let healthProvider = HealthKitActivityProvider()
    private let usageProvider: UsageProvider = DefaultUsageProvider()

    func requestHealthPermission() async {
        do {
            let granted = try await healthProvider.requestAuthorization()
            permission = granted ? .granted : .denied

            if granted {
                let moveStatus = healthProvider.status(for: .activeEnergyBurned)
                let exerciseStatus = healthProvider.status(for: .appleExerciseTime)
                let stepStatus = healthProvider.status(for: .stepCount)
                print("[ViewModel] HealthKit status - move: \(moveStatus), exercise: \(exerciseStatus), step: \(stepStatus)")
            }
        } catch {
            permission = .denied
            lastError = "Health 권한 요청 실패: \(error.localizedDescription)"
            print("[ViewModel] requestHealthPermission error: \(error.localizedDescription)")
        }
    }

    func tick(minutes: Int) {
        let delta = max(0, minutes * max(1, speedMultiplier))
        currentCharacter.elapsedMinutes += delta
        currentCharacter.lastTickAt = Date()
    }

    func runPipeline() async {
        let now = Date()
        let activity = await healthProvider.fetchTodayActivity()

        guard let activity else {
            lastError = "Health 데이터를 불러오지 못했습니다: nil 반환"
            print("[ViewModel] fetchTodayActivity returned nil")
            return
        }

        let sessions: [UsageSession]
        switch mode {
        case .manual:
            sessions = manualSessions
        default:
            sessions = await usageProvider.fetchTodaySessions(mode: mode)
        }

        let completeness = CompletenessFlags(
            moveKcal: activity.moveKcal > 0,
            exerciseMin: activity.exerciseMin > 0,
            sleep: !sessions.isEmpty,
            playCount: true,
            petCount: true
        )

        let daily = DailyState(
            date: now,
            moveKcal: activity.moveKcal,
            exerciseMin: activity.exerciseMin,
            screenEvents: sessions,
            playCount: max(0, playCount),
            petCount: max(0, petCount),
            dataSource: mode,
            completeness: completeness
        )

        print("[ViewModel] runPipeline - today moveKcal: \(activity.moveKcal), exerciseMin: \(activity.exerciseMin), steps: \(activity.steps), sessions: \(sessions.count)")


        let (weight, diff) = WeightEngine.compute(moveKcal: daily.moveKcal, exerciseMin: daily.exerciseMin)
        let sleep = SleepUsageEngine.compute(for: now, sessions: daily.screenEvents)
        let (happiness, point) = HappinessEngine.compute(playCount: daily.playCount, petCount: daily.petCount)

        let snapshot = CategorySnapshot(weight: weight, sleep: sleep.category, happiness: happiness)

        var reason = "Stage 유지"
        if StageTimerEngine.canEvolve(currentCharacter) {
            let evolved = EvolutionEngine.evolve(current: currentCharacter, snapshot: snapshot, now: now)
            currentCharacter = evolved.next
            reason = evolved.reason
        }

        output = PipelineOutput(
            daily: daily,
            snapshot: snapshot,
            character: currentCharacter,
            trace: PipelineTrace(
                sleep: sleep,
                weightDiffPct: diff,
                happinessPoint: point,
                evolutionReason: reason
            )
        )
    }

    func setManualSample() {
        manualSessions = UsageFixtures.defaultDay
    }

    var remainingMinutes: Int {
        StageTimerEngine.remainingMinutes(currentCharacter)
    }
}
