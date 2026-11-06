import SwiftUI
import Fit2216Core

/// The plan and schedule. Any day can be opened and started, which covers a missed day or doing Friday's workout on Thursday.
struct WorkoutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let week = Summary.week(plan: model.plan, logs: model.logs, model.now)
        let states = Dictionary(uniqueKeysWithValues: week.days.map { ($0.weekday, $0.state) })

        List(Plan.sort(model.plan), id: \.day) { day in
            NavigationLink {
                DayDetailView(day: day)
            } label: {
                DayRow(day: day, state: states[day.day])
            }
        }
        .navigationTitle("Workout")
    }
}

private struct DayRow: View {
    let day: TemplateDay
    let state: WeekDay.State?

    private var weekdayName: String { Calendar.current.weekdaySymbols[day.day] }
    private var muscles: String { Muscles.forDay(day).keys.map(\.label).sorted().joined(separator: " · ") }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(weekdayName).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                Spacer()
                if let badge = badge { Text(badge.0).font(.caption.bold()).foregroundStyle(badge.1) }
            }
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

    private var badge: (String, Color)? {
        switch state {
        case .done: return ("Done", .green)
        case .missed: return ("Missed", .red)
        case .today: return ("Today", .blue)
        case .skipped: return ("Skipped", .orange)
        default: return nil
        }
    }
}

struct DayDetailView: View {
    let day: TemplateDay
    @State private var showSoon = false

    var body: some View {
        List {
            if let notes = day.notes, !notes.isEmpty { Section { Text(notes) } }
            Section("Exercises") {
                ForEach(day.exercises, id: \.name) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.name + (e.optional == true ? " (optional)" : "")).font(.headline)
                        Text("\(e.sets) × \(e.reps) · rest \(Plan.clock(Double(Plan.restSeconds(e))))").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if day.type != .rest && !day.exercises.isEmpty {
                Button { showSoon = true } label: { Text("Start this workout").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.horizontal).padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .alert("Logging comes next", isPresented: $showSoon) { Button("OK", role: .cancel) {} }
    }
}

#Preview {
    NavigationStack { WorkoutView() }.environment(AppModel.sample())
}
