import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { SummaryView().profileButton() }
                .tabItem { Label("Summary", systemImage: "heart.circle") }
            NavigationStack { WorkoutView().profileButton() }
                .tabItem { Label("Workout", systemImage: "dumbbell") }
            NavigationStack { MacrosView().profileButton() }
                .tabItem { Label("Macros", systemImage: "fork.knife") }
            NavigationStack { InsightsView().profileButton() }
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

#Preview {
    RootView().environment(AppModel.sample())
}
