import Foundation
import HealthKit
import CoreLocation

@MainActor
final class HealthKitManager: ObservableObject {
    enum State: Equatable {
        case idle
        case requestingAccess
        case loading
        case ready
        case unavailable(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var latestWorkout: WorkoutSummary?

    private let store = HKHealthStore()
    private var observer: HKObserverQuery?
    private let cacheURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("latest-run.json")

    func restoreAndObserve() async {
        restoreCachedWorkout()
        guard HKHealthStore.isHealthDataAvailable() else {
            state = .unavailable("这台设备不支持健康数据，请在 iPhone 真机上运行。")
            return
        }
        do {
            try await requestAccess()
            startObservingWorkouts()
            try await refreshLatestWorkout()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func requestAccess() async throws {
        state = .requestingAccess
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)
        ].compactMap { $0 }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func refreshLatestWorkout() async throws {
        state = .loading
        guard let workout = try await latestRunningWorkout() else {
            state = .unavailable("还没有找到跑步记录。完成一次跑步并等待手表同步后再试。")
            return
        }

        async let heartRates = quantitySamples(.heartRate, for: workout)
        async let distances = quantitySamples(.distanceWalkingRunning, for: workout)
        async let locations = workoutRoute(for: workout)
        let (heartRateSamples, distanceSamples, routeLocations) = try await (heartRates, distances, locations)

        let summary = makeSummary(
            workout: workout,
            heartRateSamples: heartRateSamples,
            distanceSamples: distanceSamples,
            routeLocations: routeLocations
        )
        latestWorkout = summary
        save(summary)
        state = .ready
    }

    private func startObservingWorkouts() {
        guard observer == nil else { return }
        let type = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, error in
            guard error == nil, let self else {
                completion()
                return
            }
            Task { @MainActor in
                defer { completion() }
                try? await self.refreshLatestWorkout()
            }
        }
        observer = query
        store.execute(query)
        store.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }

    private func latestRunningWorkout() async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForWorkouts(with: .running)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.first as? HKWorkout)
                }
            }
            store.execute(query)
        }
    }

    private func quantitySamples(
        _ identifier: HKQuantityTypeIdentifier,
        for workout: HKWorkout
    ) async throws -> [HKQuantitySample] {
        guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            let predicate = HKQuery.predicateForObjects(from: workout)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func workoutRoute(for workout: HKWorkout) async -> [CLLocation] {
        let routeType = HKSeriesType.workoutRoute()
        let routes: [HKWorkoutRoute] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: HKQuery.predicateForObjects(from: workout),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                continuation.resume(returning: error == nil ? samples as? [HKWorkoutRoute] ?? [] : [])
            }
            store.execute(query)
        }
        guard let route = routes.first else { return [] }

        return await withCheckedContinuation { continuation in
            var locations: [CLLocation] = []
            let query = HKWorkoutRouteQuery(route: route) { _, batch, done, error in
                if let error {
                    _ = error
                    continuation.resume(returning: [])
                    return
                }
                locations.append(contentsOf: batch ?? [])
                if done {
                    continuation.resume(returning: locations.sorted { $0.timestamp < $1.timestamp })
                }
            }
            store.execute(query)
        }
    }

    private func makeSummary(
        workout: HKWorkout,
        heartRateSamples: [HKQuantitySample],
        distanceSamples: [HKQuantitySample],
        routeLocations: [CLLocation]
    ) -> WorkoutSummary {
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let heartRate = heartRateSamples.map {
            HeartRatePoint(
                secondsFromStart: max(0, $0.startDate.timeIntervalSince(workout.startDate)),
                beatsPerMinute: $0.quantity.doubleValue(for: bpm)
            )
        }

        let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let distance = workout.statistics(for: distanceType)?
            .sumQuantity()?.doubleValue(for: .meter())
            ?? distanceSamples.reduce(0) { $0 + $1.quantity.doubleValue(for: .meter()) }
        let energy = workout.statistics(for: energyType)?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        return WorkoutSummary(
            id: workout.uuid,
            startDate: workout.startDate,
            duration: workout.duration,
            distanceMeters: distance,
            activeEnergyKcal: energy,
            heartRate: heartRate,
            splits: routeLocations.count > 1
                ? makeRouteSplits(routeLocations)
                : makeSplits(samples: distanceSamples, workout: workout, totalDistance: distance)
        )
    }

    private func makeRouteSplits(_ locations: [CLLocation]) -> [RunSplit] {
        var distance = 0.0
        var boundary = 1_000.0
        var splitStart = locations[0].timestamp
        var result: [RunSplit] = []

        for index in 1..<locations.count {
            let previous = locations[index - 1]
            let current = locations[index]
            let segment = current.distance(from: previous)
            guard segment > 0, segment < 200 else { continue }
            let before = distance
            distance += segment

            while distance >= boundary {
                let fraction = min(1, max(0, (boundary - before) / segment))
                let crossing = previous.timestamp.addingTimeInterval(
                    current.timestamp.timeIntervalSince(previous.timestamp) * fraction
                )
                result.append(RunSplit(kilometer: result.count + 1, duration: crossing.timeIntervalSince(splitStart)))
                splitStart = crossing
                boundary += 1_000
            }
        }
        return result
    }

    private func makeSplits(
        samples: [HKQuantitySample],
        workout: HKWorkout,
        totalDistance: Double
    ) -> [RunSplit] {
        var nextBoundary = 1_000.0
        var accumulatedDistance = 0.0
        var splitStart = workout.startDate
        var result: [RunSplit] = []

        for sample in samples {
            let meters = sample.quantity.doubleValue(for: .meter())
            guard meters > 0 else { continue }
            let before = accumulatedDistance
            accumulatedDistance += meters

            while accumulatedDistance >= nextBoundary {
                let fraction = min(1, max(0, (nextBoundary - before) / meters))
                let boundaryDate = sample.startDate.addingTimeInterval(
                    sample.endDate.timeIntervalSince(sample.startDate) * fraction
                )
                result.append(RunSplit(
                    kilometer: result.count + 1,
                    duration: boundaryDate.timeIntervalSince(splitStart)
                ))
                splitStart = boundaryDate
                nextBoundary += 1_000
            }
        }

        if result.isEmpty, totalDistance >= 1_000 {
            let fullKilometers = Int(totalDistance / 1_000)
            return (1...fullKilometers).map {
                RunSplit(kilometer: $0, duration: workout.duration / (totalDistance / 1_000))
            }
        }
        return result
    }

    private func save(_ workout: WorkoutSummary) {
        do {
            try FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(workout).write(to: cacheURL, options: .atomic)
        } catch {
            // Cache failure must not prevent the current workout from being shown.
        }
    }

    private func restoreCachedWorkout() {
        guard let data = try? Data(contentsOf: cacheURL),
              let workout = try? JSONDecoder().decode(WorkoutSummary.self, from: data)
        else { return }
        latestWorkout = workout
        state = .ready
    }
}
