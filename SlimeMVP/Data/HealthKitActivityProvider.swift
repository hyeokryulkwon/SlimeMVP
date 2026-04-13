import Foundation
import HealthKit

final class HealthKitActivityProvider {
    private let store = HKHealthStore()
    private let logPrefix = "[HealthKit]"
    private(set) var lastFetchDebugLines: [String] = []

    struct TodayActivity {
        let moveKcal: Double
        let steps: Double
        let sleepMinutes: Int
        let moveQuerySucceeded: Bool
        let stepsQuerySucceeded: Bool
        let sleepQuerySucceeded: Bool
        let sleepSource: String
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

        print("[HealthKitDebug] Creating quantity types for energy, steps, and sleep...")
        guard
            let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let steps = HKObjectType.quantityType(forIdentifier: .stepCount),
            let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        else {
            print("[HealthKitDebug] EARLY RETURN: Failed to create quantity types")
            print("\(logPrefix) Required quantity type not available")
            return false
        }
        
        print("[HealthKitDebug] Successfully created all quantity types")

        let readTypes: Set<HKObjectType> = [energy, steps, sleep]
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
                    let stepsStatus = self.store.authorizationStatus(for: steps)
                    let sleepStatus = self.store.authorizationStatus(for: sleep)
                    print("[HealthKitDebug] Authorization statuses - energy: \(energyStatus.rawValue), steps: \(stepsStatus.rawValue), sleep: \(sleepStatus.rawValue)")
                    print("\(self.logPrefix) Sharing authorization statuses - energy: \(energyStatus), steps: \(stepsStatus), sleep: \(sleepStatus)")
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
        var debugLines: [String] = []
        // Fetch each metric independently to prevent one failure from killing all
        let move: Double
        let steps: Double
        let sleepMinutes: Int
        let moveQuerySucceeded: Bool
        let stepsQuerySucceeded: Bool
        let sleepQuerySucceeded: Bool
        let sleepSource: String
        
        do {
            move = try await sumQuantity(for: .activeEnergyBurned, unit: .kilocalorie()) ?? 0
            moveQuerySucceeded = true
            debugLines.append("Move Query: success (\(Int(move)) kcal)")
        } catch {
            print("[HealthKitDebug] Error fetching activeEnergyBurned: \(error.localizedDescription). Using 0.")
            move = 0
            moveQuerySucceeded = false
            debugLines.append("Move Query: failed (\(error.localizedDescription))")
        }
        
        do {
            steps = try await sumQuantity(for: .stepCount, unit: .count()) ?? 0
            stepsQuerySucceeded = true
            debugLines.append("Steps Query: success (\(Int(steps)))")
        } catch {
            print("[HealthKitDebug] Error fetching stepCount: \(error.localizedDescription). Using 0.")
            steps = 0
            stepsQuerySucceeded = false
            debugLines.append("Steps Query: failed (\(error.localizedDescription))")
        }

        do {
            let sleepResult = try await fetchRecentSleepMinutes()
            sleepMinutes = sleepResult.minutes
            sleepQuerySucceeded = true
            sleepSource = sleepResult.source
            debugLines.append("Sleep Query: success (\(sleepMinutes) min, source: \(sleepSource))")
        } catch {
            print("[HealthKitDebug] Error fetching sleepAnalysis: \(error.localizedDescription). Using 0.")
            sleepMinutes = 0
            sleepQuerySucceeded = false
            sleepSource = "failed"
            debugLines.append("Sleep Query: failed (\(error.localizedDescription))")
        }

        lastFetchDebugLines = debugLines
        print("[HealthKitDebug] All queries completed - move: \(move), steps: \(steps), sleepMinutes: \(sleepMinutes)")

        let activity = TodayActivity(
            moveKcal: move,
            steps: steps,
            sleepMinutes: sleepMinutes,
            moveQuerySucceeded: moveQuerySucceeded,
            stepsQuerySucceeded: stepsQuerySucceeded,
            sleepQuerySucceeded: sleepQuerySucceeded,
            sleepSource: sleepSource
        )
        print("[HealthKitDebug] fetchTodayActivity returning activity: move=\(activity.moveKcal), steps=\(activity.steps), sleepMinutes=\(activity.sleepMinutes)")
        print("\(logPrefix) fetchTodayActivity result: move=\(activity.moveKcal), steps=\(activity.steps), sleepMinutes=\(activity.sleepMinutes)")
        
        return activity
    }

    func categoryStatus(for identifier: HKCategoryTypeIdentifier) -> HKAuthorizationStatus {
        guard let type = HKObjectType.categoryType(forIdentifier: identifier) else {
            return .notDetermined
        }
        return store.authorizationStatus(for: type)
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
        
        // Debug: Print exact local date range and timezone
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timeZone = TimeZone.current
        let startLocal = formatter.string(from: start)
        let endLocal = formatter.string(from: end)
        print("[HealthKitDebug] ===== QUERY DATE/TIME DEBUG =====")
        print("[HealthKitDebug] User timezone: \(timeZone.abbreviation() ?? timeZone.identifier) (UTC\(String(format: "%+.1f", Double(timeZone.secondsFromGMT()) / 3600)))")
        print("[HealthKitDebug] Current local time: \(Date())")
        print("[HealthKitDebug] Query type: \(identifier.rawValue)")
        print("[HealthKitDebug] startOfDay (local): \(start)")
        print("[HealthKitDebug] startOfDay (ISO8601): \(startLocal)")
        print("[HealthKitDebug] endOfDay (local): \(end)")
        print("[HealthKitDebug] endOfDay (ISO8601): \(endLocal)")
        print("[HealthKitDebug] ===== END DATE/TIME DEBUG =====")
        
        print("[HealthKitDebug] Query date range for \(identifier.rawValue): \(start) to \(end)")

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            print("[HealthKitDebug] Executing cumulativeSum query for \(identifier.rawValue) from \(start) to \(end)")
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                print("[HealthKitDebug] Query type: \(type.identifier)")
                print("[HealthKitDebug] startDate: \(start)")
                print("[HealthKitDebug] endDate: \(Date())")
                
                if let error = error {
                    print("[HealthKitDebug] \(type.identifier) error: \(error.localizedDescription)")
                } else if let stats = stats {
                    print("[HealthKitDebug] stats exists for \(type.identifier)")
                    
                    if let sum = stats.sumQuantity() {
                        print("[HealthKitDebug] sumQuantity exists for \(type.identifier): \(sum)")
                        
                        if identifier == .activeEnergyBurned {
                            print("[HealthKitDebug] kcal = \(sum.doubleValue(for: .kilocalorie()))")
                        }
                        
                    } else {
                        print("[HealthKitDebug] sumQuantity is nil for \(type.identifier)")
                    }
                } else {
                    print("[HealthKitDebug] statistics is nil for \(type.identifier)")
                }
                
                print("[HealthKitDebug] Query callback for \(identifier.rawValue) - error: \(error?.localizedDescription ?? "nil"), stats: \(stats != nil)")
                
                if let error = error as? NSError {
                    if error.domain == "com.apple.healthkit" && error.code == 11 {
                        print("[HealthKitDebug] NON-FATAL: HealthKit Code=11 (No data available) for \(identifier.rawValue). Treating as 0.")
                        print("\(self.logPrefix) \(identifier.rawValue) has no data for today (Code=11). Treating as 0.")
                        continuation.resume(returning: 0)
                        return
                    } else {
                        print("[HealthKitDebug] THROWING ERROR: statistics query error (\(identifier.rawValue)): \(error.localizedDescription) (domain: \(error.domain), code: \(error.code))")
                        print("\(self.logPrefix) statistics query error (\(identifier.rawValue)): \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                        return
                    }
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

    private func fetchRecentSleepMinutes() async throws -> (minutes: Int, source: String) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            print("[HealthKitDebug] sleepAnalysis type is unavailable")
            return (0, "unavailable")
        }

        let cal = Calendar.current
        let now = Date()
        guard let start = cal.date(byAdding: .hour, value: -24, to: now) else {
            return (0, "range unavailable")
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let categorySamples = (samples as? [HKCategorySample]) ?? []
                let asleepSamples = categorySamples.filter { self.isAsleepSample($0) }
                let inBedSamples = categorySamples.filter { $0.value == HKCategoryValueSleepAnalysis.inBed.rawValue }

                let asleepMinutes = asleepSamples.reduce(0) { partial, sample in
                    partial + max(0, Int(sample.endDate.timeIntervalSince(sample.startDate) / 60.0))
                }
                let inBedMinutes = inBedSamples.reduce(0) { partial, sample in
                    partial + max(0, Int(sample.endDate.timeIntervalSince(sample.startDate) / 60.0))
                }

                let result: (minutes: Int, source: String)
                if asleepMinutes > 0 {
                    result = (asleepMinutes, "asleep")
                } else if inBedMinutes > 0 {
                    result = (inBedMinutes, "inBed fallback")
                } else {
                    result = (0, "no samples")
                }

                print("[HealthKitDebug] sleepAnalysis samples: total=\(categorySamples.count), asleep=\(asleepSamples.count), inBed=\(inBedSamples.count), result=\(result.minutes), source=\(result.source)")
                continuation.resume(returning: result)
            }
            self.store.execute(query)
        }
    }

    private func isAsleepSample(_ sample: HKCategorySample) -> Bool {
        sample.value != HKCategoryValueSleepAnalysis.inBed.rawValue &&
        sample.value != HKCategoryValueSleepAnalysis.awake.rawValue
    }
    
    private func debugFetchSamples(type: HKQuantityType, identifier: HKQuantityTypeIdentifier, unit: HKUnit, startDate: Date, endDate: Date) async {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [])
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors) { _, samples, error in
                print("[HealthKitDebug] SampleQuery type: \(identifier.rawValue)")
                print("[HealthKitDebug] SampleQuery date range: \(startDate) to \(endDate)")
                
                if let error = error {
                    print("[HealthKitDebug] SampleQuery error for \(identifier.rawValue): \(error.localizedDescription)")
                    continuation.resume()
                    return
                }
                
                guard let samples = samples else {
                    print("[HealthKitDebug] Sample count for \(identifier.rawValue): 0 (samples is nil)")
                    continuation.resume()
                    return
                }
                
                print("[HealthKitDebug] Sample count for \(identifier.rawValue): \(samples.count)")
                
                // Log first up to 5 samples
                for (index, sample) in samples.prefix(5).enumerated() {
                    if let quantitySample = sample as? HKQuantitySample {
                        let value = quantitySample.quantity.doubleValue(for: unit)
                        let source = quantitySample.source.name
                        print("[HealthKitDebug]   Sample \(index) - start: \(quantitySample.startDate), end: \(quantitySample.endDate), value: \(value) \(unit.unitString), source: \(source)")
                    }
                }
                
                continuation.resume()
            }
            self.store.execute(query)
        }
    }
}
