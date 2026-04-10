import SwiftUI

@main
struct LeafLogApp: App {
    @StateObject private var store = PlantStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .task {
                    await NotificationManager.shared.requestAuthorizationIfNeeded()
                    await store.refreshNotifications()
                }
        }
    }
}
