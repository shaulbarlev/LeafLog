import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                PlantListView()
            }
            .tabItem {
                Label("Plants", systemImage: "leaf")
            }

            NavigationStack {
                WateringCalendarView()
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
        }
    }
}
