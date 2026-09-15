import SwiftUI

@main
struct AppleFleetsApp: App {
    @StateObject private var healthStore = HealthKitManager()
    @StateObject private var bridge = RunBridgeServer()
    @StateObject private var agentFleet = AgentFleetClient()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(healthStore)
                .environmentObject(bridge)
                .environmentObject(agentFleet)
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
