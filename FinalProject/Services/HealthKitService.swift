import Foundation
import HealthKit

@MainActor
final class HealthKitService: ObservableObject {
    static let shared = HealthKitService()

    @Published var todaySteps:   Int    = 0
    @Published var sleepHours:   Double = 0
    @Published var isAuthorized: Bool   = false

    private let hkStore = HKHealthStore()

    private init() {}

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        var readTypes = Set<HKObjectType>()
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            readTypes.insert(steps)
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            readTypes.insert(sleep)
        }
        guard !readTypes.isEmpty else { return }

        do {
            try await hkStore.requestAuthorization(toShare: [], read: readTypes)
            // BUG FIX: requestAuthorization does NOT throw when user denies.
            // Check actual status for at least one type to set isAuthorized correctly.
            if let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) {
                let status = hkStore.authorizationStatus(for: stepsType)
                isAuthorized = (status == .sharingAuthorized)
            } else {
                isAuthorized = true
            }
            await loadData()
        } catch {
            isAuthorized = false
            print("HealthKit authorization failed: \(error)")
        }
    }

    func loadData() async {
        async let steps = fetchTodaySteps()
        async let sleep = fetchLastNightSleep()
        todaySteps = await steps
        sleepHours = await sleep
    }

    // MARK: - Step count (today)

    private func fetchTodaySteps() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start     = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let steps = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(steps))
            }
            hkStore.execute(query)
        }
    }

    // MARK: - Sleep (last 16 hours)

    private func fetchLastNightSleep() async -> Double {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let end       = Date()
        let start     = Calendar.current.date(byAdding: .hour, value: -16, to: end) ?? end
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort      = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 30,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let samples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]
                let totalSeconds = samples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                continuation.resume(returning: totalSeconds / 3600.0)
            }
            hkStore.execute(query)
        }
    }
}
