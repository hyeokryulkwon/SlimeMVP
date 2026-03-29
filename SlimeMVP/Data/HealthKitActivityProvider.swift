import Foundation
import HealthKit

final class HealthKitActivityProvider {
    private let store = HKHealthStore()
    private let logPrefix = "[HealthKit]"

    struct TodayActivity {
        let moveKcal: Double
        let exerciseMin: Double
        let steps: Double
    }

    var isHealthDataAvailable: Bool {
        let available = HKHealthStore.isHealthDataAvailable()
        print("[HealthKitDebug] HKHealthStore.isHealthDataAvailable() = \(available)")
        return available
    }

    func requestAuthorization() async throws -> Bool {
        guard isHealthDataAvailable else {
            print("[HealthKitDebug] EARLY RETURN: Health data not available on this device")
            print("\(logPrefix) Health data not available on this device")
            return false
        }

        print("[HealthKitDebug] Creating quantity types for energy, exercise, steps...")
        guard
            let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let exercise = HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            let steps = HKObjectType.quantityType(forIdentifier: .stepCount)
        else {
            print("[HealthKitDebug] EARLY RETURN: Failed to create quantity types")
            print("\(logPrefix) Required quantity type not available")
            return false
        }
        
        print("[HealthKitDebug] Successfully created all quantity types")

        let readTypes: Set<HKObjectType> = [energy, exercise, steps]
        print("\(logPrefix) Requesting HealthKit read authorization for: \(readTypes.map { $0.identifier }.sorted())")
        print("[HealthKitDebug] readTypes count: \(readTypes.count)")

        return try await withCheckedThrowingContinuation { continuation in
            store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
                print("[HealthKitDebug] requestAuthorization callback - success: \(success), error: \(error?.localizedDescription ?? "nil")")
                if let error {
                    print("\(self.logPrefix) requestAuthorization error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    print("\(self.logPrefix) requestAuthorization success: \(success)")
                    let energyStatus = self.store.authorizationStatus(for: energy)
                    let exerciseStatus = self.store.authorizationStatus(for: exercise)
                    let stepsStatus = self.store.authorizationStatus(for: steps)
                    print("[HealthKitDebug] Authorization statuses - energy: \(energyStatus.rawValue), exercise: \(exerciseStatus.rawValue), steps: \(stepsStatus.rawValue)")
                    print("\(self.logPrefix) Sharing authorization statuses - energy: \(energyStatus), exercise: \(exerciseStatus), steps: \(stepsStatus)")
                    print("\(self.logPrefix) Note: HKAuthorizationStatus reflects sharing permission, not read permission. Read access is verified by query results.")
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func status(for identifier: HKQuantityTypeIdentifier) -> HKAuthorizationStatus {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return .notDetermined
        }
        return store.authorizationStatus(for: type)
    }

    func fetchTodayActivity() async -> TodayActivity? {
        print("[HealthKitDebug] fetchTodayActivity started at \(Date())")
        let energyStatus = status(for: .activeEnergyBurned)
        let exerciseStatus = status(for: .appleExerciseTime)
        let stepsStatus = status(for: .stepCount)
        print("[HealthKitDebug] Authorization statuses - energy: \(energyStatus.rawValue), exercise: \(exerciseStatus.rawValue), steps: \(stepsStatus.rawValue)")
        print("\(logPrefix) Sharing authorization statuses - energy: \(energyStatus), exercise: \(exerciseStatus), steps: \(stepsStatus)")
        do {
            async let move = sumQuantity(for: .activeEnergyBurned, unit: .kilocalorie())
            async let exercise = sumQuantity(for: .appleExerciseTime, unit: .minute())
            async let steps = sumQuantity(for: .stepCount, unit: .count())

            print("[HealthKitDebug] Awaiting all three queries...")
            let result = try await (move, exercise, steps)
            print("[HealthKitDebug] All queries completed - move: \(result.0 ?? -999), exercise: \(result.1 ?? -999), steps: \(result.2 ?? -999)")

            let activity = TodayActivity(
                moveKcal: result.0 ?? 0,
                exerciseMin: result.1 ?? 0,
                steps: result.2 ?? 0
            )
            print("[HealthKitDebug] fetchTodayActivity returning activity: move=\(activity.moveKcal), exercise=\(activity.exerciseMin), steps=\(activity.steps)")
            print("\(logPrefix) fetchTodayActivity result: move=\(activity.moveKcal), exercise=\(activity.exerciseMin), steps=\(activity.steps)")
            return activity
        } catch {
            print("[HealthKitDebug] EARLY RETURN nil: fetchTodayActivity failed with error: \(error)")
            print("\(logPrefix) fetchTodayActivity failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func sumQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> Double? {
        print("[HealthKitDebug] sumQuantity called for \(identifier.rawValue)")
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            print("[HealthKitDebug] EARLY RETURN nil: quantity type for \(identifier.rawValue) is nil")
            print("\(logPrefix) quantity type for \(identifier.rawValue) is nil")
            return nil
        }
        
        print("[HealthKitDebug] Successfully created quantity type for \(identifier.rawValue)")

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else {
            print("[HealthKitDebug] EARLY RETURN nil: failed to compute start/end for today")
            print("\(logPrefix) failed to compute start/end for today")
            return nil
        }
        
        print("[HealthKitDebug] Query date range for \(identifier.rawValue): \(start) to \(end)")

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            print("[HealthKitDebug] Executing cumulativeSum query for \(identifier.rawValue) from \(start) to \(end)")
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                print("[HealthKitDebug] Query callback for \(identifier.rawValue) - error: \(error?.localizedDescription ?? "nil"), stats: \(stats != nil)")
                
                if let error {
                    print("[HealthKitDebug] THROWING ERROR: statistics query error (\(identifier.rawValue)): \(error.localizedDescription)")
                    print("\(self.logPrefix) statistics query error (\(identifier.rawValue)): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }

                if let stats = stats {
                    print("[HealthKitDebug] stats object exists for \(identifier.rawValue)")
                    if let sum = stats.sumQuantity() {
                        let value = sum.doubleValue(for: unit)
                        print("[HealthKitDebug] sumQuantity exists, value: \(value)")
                        print("\(self.logPrefix) \(identifier.rawValue) -> \(value) in unit \(unit)")
                        continuation.resume(returning: value)
                    } else {
                        print("[HealthKitDebug] stats.sumQuantity() is nil for \(identifier.rawValue). Returning 0.")
                        print("\(self.logPrefix) \(identifier.rawValue) returned no data (sumQuantity is nil). Treating as 0.")
                        continuation.resume(returning: 0)
                    }
                } else {
                    print("[HealthKitDebug] stats object is nil for \(identifier.rawValue). Returning 0.")
                    print("\(self.logPrefix) \(identifier.rawValue) returned no data (stats is nil). Treating as 0.")
                    continuation.resume(returning: 0)
                }
            }
            self.store.execute(query)
            print("[HealthKitDebug] Query execution enqueued for \(identifier.rawValue)")
        }
    }
    
    // Debug function to check last 7 days of step count
    func debugFetchWeeklySteps() async -> Double? {
        print("[HealthKitDebug] DEBUG: Fetching last 7 days of step count...")
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            print("[HealthKitDebug] DEBUG: Cannot create stepCount type")
            return nil
        }
        
        let cal = Calendar.current
        let end = Date()
        guard let start = cal.date(byAdding: .day, value: -7, to: end) else {
            print("[HealthKitDebug] DEBUG: Cannot compute 7-day range")
            return nil
        }
        
        print("[HealthKitDebug] DEBUG: 7-day query range: \(start) to \(end)")
        
        return try? await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error {
                    print("[HealthKitDebug] DEBUG: 7-day query error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                if let stats = stats, let sum = stats.sumQuantity()?.doubleValue(for: .count()) {
                    print("[HealthKitDebug] DEBUG: 7-day step count = \(sum)")
                    continuation.resume(returning: sum)
                } else {
                    print("[HealthKitDebug] DEBUG: 7-day query returned no data")
                    continuation.resume(returning: 0)
                }
            }
            self.store.execute(query)
        }
    }
}
