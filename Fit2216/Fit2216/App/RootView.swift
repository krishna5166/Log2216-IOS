import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { SummaryView().profileButton() }
                .tabItem { Label("Summary", systemImage: "heart.circle") }
            NavigationStack { WorkoutView().profileButton() }
                .tabItem { Label("Workout", systemImage: "dumbbell") }
            NavigationStack { ComingSoonView(title: "Macros", symbol: "fork.knife").profileButton() }
                .tabItem { Label("Macros", systemImage: "fork.knife") }
            NavigationStack { ComingSoonView(title: "Insights", symbol: "chart.line.uptrend.xyaxis").profileButton() }
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

#Preview {
    RootView().environment(AppModel())
}
