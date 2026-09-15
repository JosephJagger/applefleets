import SwiftUI

@main
struct AppleFleetsApp: App {
    @StateObject private var healthStore = HealthKitManager()
    @StateObject private var bridge = RunBridgeServer()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(healthStore)
                .environmentObject(bridge)
                .task {
                    bridge.start()
                    await healthStore.restoreAndObserve()
                    if let workout = healthStore.latestWorkout {
                        bridge.publish(workout)
                    }
                }
        }
    }
}
