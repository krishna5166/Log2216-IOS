import SwiftUI
import Fit2216Core

struct WorkoutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List(Plan.sort(model.plan), id: \.day) { day in
            DayRow(day: day)
        }
        .navigationTitle("Workout")
    }
}

private struct DayRow: View {
    let day: TemplateDay

    private var weekdayName: String { Calendar.current.weekdaySymbols[day.day] }
    private var muscles: String { Muscles.forDay(day).keys.map(\.label).sorted().joined(separator: " · ") }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(weekdayName).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            Text(day.name).font(.headline)
            if day.type == .rest || day.exercises.isEmpty {
                Text("Rest").font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text(muscles).font(.subheadline).foregroundStyle(.secondary)
                Text("\(day.exercises.count) exercises · \(Plan.plannedSets(day)) sets").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack { WorkoutView() }.environment(AppModel.sample())
}
