import SwiftUI
import Fit2216Core

/// The plan and schedule. Any day can be opened and started, which covers a missed day or doing Friday's workout on Thursday.
struct WorkoutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let week = Summary.week(plan: model.plan, logs: model.logs, model.now)
        let states = Dictionary(uniqueKeysWithValues: week.days.map { ($0.weekday, $0.state) })

        ScrollView {
            VStack(spacing: 12) {
                ForEach(Plan.sort(model.plan), id: \.day) { day in
                    NavigationLink {
                        DayDetailView(day: day)
                    } label: {
                        DayRow(day: day, state: states[day.day])
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle("Workout")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { NavigationLink("Edit plan") { PlanEditorView() } }
        }
    }
}

private struct DayRow: View {
    let day: TemplateDay
    let state: WeekDay.State?

    private var weekdayName: String { Calendar.current.weekdaySymbols[day.day] }
    private var muscles: String { Muscles.forDay(day).keys.map(\.label).sorted().joined(separator: " · ") }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(weekdayName.uppercased()).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(day.name).font(.system(size: 24, weight: .bold, design: .rounded))
                if day.type == .rest || day.exercises.isEmpty {
                    Text("Rest day").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text(muscles).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 14) {
                        BigValue(value: "\(day.exercises.count)", unit: "exercises", color: Theme.lime, size: 22)
                        BigValue(value: "\(Plan.plannedSets(day))", unit: "sets", color: Theme.cyan, size: 22)
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 10) {
                if let badge {
                    Text(badge.0).font(.caption.weight(.bold)).foregroundStyle(badge.1)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(badge.1.opacity(0.18), in: Capsule())
                }
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
        }
        .card()
        .overlay { if state == .today { RoundedRectangle(cornerRadius: 22).stroke(Theme.lime, lineWidth: 2) } }
    }

    private var badge: (String, Color)? {
        switch state {
        case .done: return ("Done", Theme.lime)
        case .missed: return ("Missed", Theme.pink)
        case .today: return ("Today", Theme.lime)
        case .skipped: return ("Skipped", Color.orange)
        default: return nil
        }
    }
}

struct DayDetailView: View {
    @Environment(AppModel.self) private var model
    let day: TemplateDay
    @State private var logging: LoggingTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let notes = day.notes, !notes.isEmpty {
                    Text(notes).font(.subheadline).card()
                }
                ForEach(day.exercises, id: \.name) { e in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(e.name + (e.optional == true ? " (optional)" : "")).font(.system(size: 20, weight: .semibold, design: .rounded))
                            Text("rest \(Plan.clock(Double(Plan.restSeconds(e))))").font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        BigValue(value: "\(e.sets) × \(e.reps)", color: Theme.lime, size: 24)
                    }
                    .card()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle(day.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if day.type != .rest && !day.exercises.isEmpty {
                Button { logging = LoggingTarget(day: day) } label: { Text("Start this workout").limeCapsule(enabled: model.canLog) }
                    .buttonStyle(.plain)
                    .disabled(!model.canLog)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(.bar)
            }
        }
        .fullScreenCover(item: $logging) { LoggingView(day: $0.day) }
    }
}

#Preview {
    NavigationStack { WorkoutView() }.environment(AppModel.sample())
}
