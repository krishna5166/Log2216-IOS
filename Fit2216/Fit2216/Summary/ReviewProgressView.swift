import SwiftUI
import Fit2216Core

/// After a workout: how each of its lifts has moved, and your workouts per week. Works from the very first session.
struct ReviewProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let day: TemplateDay
    let onEdit: () -> Void

    var body: some View {
        let now = model.now
        let unit = model.profile.gymUnit
        let lifts = Insights.liftHistory(model.logs)
        let weeks = Insights.weeklyStats(model.logs, plan: model.plan, now, weeks: Insights.chartWeeks(model.logs, now, max: 8))

        NavigationStack {
            List {
                ForEach(day.exercises, id: \.name) { e in
                    let points = lifts[e.name] ?? []
                    Section(e.name) {
                        if points.isEmpty {
                            Text("Nothing logged yet.").foregroundStyle(.secondary)
                        } else if points.count == 1, let p = points.first {
                            Text("First session: \(Format.weight(kg: p.weight, unit: unit)) × \(Int(p.reps)). Log it once more and the graph starts.").font(.footnote).foregroundStyle(.secondary)
                        } else if let first = points.first, let last = points.last {
                            let change = Units.fromKg(last.e1rm - first.e1rm, to: unit)
                            Text("Best set \(Format.weight(kg: last.weight, unit: unit)) × \(Int(last.reps)) · estimated max \(change >= 0 ? "up" : "down") \(Units.tidy(abs(change))) \(unit.rawValue) since \(Format.date(first.date))").font(.subheadline)
                            LiftChart(points: points, unit: unit)
                        }
                    }
                }
                Section("Workouts per week") { WeeklyWorkoutsChart(weeks: weeks) }
            }
            .navigationTitle("Progress · \(day.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Edit workout", action: onEdit) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}
