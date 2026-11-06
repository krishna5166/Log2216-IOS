import SwiftUI
import Fit2216Core

/// Strength and volume by body part, body weight against your goal, and how consistent you have been.
struct InsightsView: View {
    @Environment(AppModel.self) private var model
    @State private var showWeighIn = false
    @State private var macroPercents: [String: Int] = [:]

    var body: some View {
        let now = model.now
        let stats = MuscleInsights.stats(plan: model.plan, logs: model.logs, now)
        let flags = MuscleInsights.balance(stats: stats, plan: model.plan)
        let weights = model.weights.sorted { $0.date < $1.date }
        let weeks = Insights.weeklyStats(model.logs, plan: model.plan, now, weeks: Insights.chartWeeks(model.logs, now, max: 8))
        let records = Insights.recentPRs(Insights.liftHistory(model.logs), now)
        let baseline = Insights.baselineWeight(heightCm: model.profile.heightCm, targetWeightKg: model.profile.targetWeightKg)
        let progression = Progress.progression(plan: model.plan, logs: model.logs, unit: model.profile.gymUnit, now)
        let recap = Recap.week(plan: model.plan, logs: model.logs, weights: model.weights, percents: macroPercents, now)
        let calendar = Recap.calendarWeeks(plan: model.plan, logs: model.logs, percents: macroPercents, now)
        let today = Dates.localDate(now)
        let macroDays: [(date: String, pct: Int?)] = (0..<7).map { i in let d = Dates.addDays(today, i - 6); return (date: d, pct: macroPercents[d]) }

        List {
            Section("Body weight") {
                if weights.count >= 2 {
                    WeightChart(entries: weights, unit: model.profile.bodyUnit, baselineKg: baseline?.kg, goal: model.profile.goal)
                    legend(goal: model.profile.goal, hasBaseline: baseline != nil)
                } else {
                    Text("Log at least two days of weight to see your graph.").font(.footnote).foregroundStyle(.secondary)
                }
                if let summary = Summary.body(weights: weights, profile: model.profile, now) {
                    LabeledContent("Latest", value: Format.weight(kg: summary.latestKg, unit: model.profile.bodyUnit))
                    if let pace = summary.perWeekKg { LabeledContent("Pace", value: paceText(pace)) }
                }
                Button("Log weight") { showWeighIn = true }
                NavigationLink("All weigh-ins") { WeightHistoryView() }
            }

            Section {
                if progression.raise.isEmpty && progression.stalled.isEmpty {
                    Text("Nothing to change yet. Keep logging.").font(.footnote).foregroundStyle(.secondary)
                }
                ForEach(progression.raise, id: \.name) { r in
                    Label("\(r.name): \(Units.tidy(r.from)) → \(Units.tidy(r.to)) \(model.profile.gymUnit.rawValue)", systemImage: "arrow.up.circle").font(.subheadline)
                }
                ForEach(progression.stalled, id: \.name) { st in
                    Label("\(st.name) has stalled; try \(Units.tidy(st.deloadTo)) \(model.profile.gymUnit.rawValue) for a week", systemImage: "pause.circle").font(.subheadline)
                }
            } header: {
                Text("Next week")
            } footer: {
                Text(progression.deload ? "Two or more lifts have stalled, which usually means tiredness rather than one bad lift. A lighter week (about 90% of the working weight) is worth trying. Suggestions only; nothing in your plan changes." : "Suggestions only; nothing in your plan changes.")
            }

            Section(recap.label) {
                LabeledContent("Workouts", value: "\(recap.done) of \(recap.planned)")
                ForEach(recap.records, id: \.name) { r in
                    Label("\(r.name) \(Format.weight(kg: r.weightKg, unit: model.profile.gymUnit)) × \(Int(r.reps))", systemImage: "trophy").font(.subheadline)
                }
                if let change = recap.changeKg {
                    LabeledContent("Weight", value: "\(change >= 0 ? "+" : "")\(Units.tidy(Units.fromKg(change, to: model.profile.bodyUnit))) \(model.profile.bodyUnit.rawValue)")
                }
                if let avg = recap.macroAvg { LabeledContent("Food targets", value: "\(avg)% on average (\(recap.macroDays) days)") }
            }

            Section("Consistency") { ConsistencyGrid(weeks: calendar) }

            if !flags.isEmpty {
                Section("Balance") {
                    ForEach(flags, id: \.title) { flag in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(flag.title).font(.headline)
                            Text(flag.detail).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Strength by muscle") {
                if stats.isEmpty {
                    Text("Log a few workouts and your muscles show up here.").foregroundStyle(.secondary)
                } else {
                    ForEach(stats, id: \.muscle) { stat in
                        NavigationLink {
                            MuscleDetailView(stat: stat, unit: model.profile.gymUnit)
                        } label: {
                            MuscleRow(stat: stat)
                        }
                    }
                }
            }

            if !records.isEmpty {
                Section("Recent personal bests") {
                    ForEach(records, id: \.name) { r in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.headline)
                            Text("\(Format.weight(kg: r.weight, unit: model.profile.gymUnit)) × \(Int(r.reps)) · \(Format.date(r.date))").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Workouts per week") {
                WeeklyWorkoutsChart(weeks: weeks)
                let counts = Insights.weekCounts(model.plan, model.logs, now)
                LabeledContent("This week", value: "\(counts.done) of \(counts.planned)")
            }

            if macroDays.contains(where: { $0.pct != nil }) {
                Section("Food targets, last 7 days") { MacroDaysChart(days: macroDays) }
            }

            Section {
                NavigationLink("All lifts") { LiftsListView() }
                NavigationLink("Past sessions") { PastSessionsView() }
            }
        }
        .navigationTitle("Insights")
        .sheet(isPresented: $showWeighIn) { WeighInSheet() }
        .task { await loadMacroDays() }
    }

    private func loadMacroDays() async {
        guard let uid = model.uid else { return }
        let from = Dates.addDays(Dates.localDate(model.now), -34)
        macroPercents = (try? await model.firestore.loadFoodPercents(uid: uid, from: from)) ?? [:]
    }

    private func paceText(_ kgPerWeek: Double) -> String {
        let v = Units.fromKg(kgPerWeek, to: model.profile.bodyUnit)
        return "\(v >= 0 ? "+" : "")\(String(format: "%.1f", v)) \(model.profile.bodyUnit.rawValue) a week"
    }

    private func legend(goal: Goal?, hasBaseline: Bool) -> some View {
        HStack(spacing: 12) {
            Label("7-day average", systemImage: "line.diagonal").font(.caption2)
            if hasBaseline {
                Label("Right side of target", systemImage: "square.fill").foregroundStyle(.green.opacity(0.6)).font(.caption2)
                Label("Wrong side", systemImage: "square.fill").foregroundStyle(.red.opacity(0.6)).font(.caption2)
            }
        }
        .foregroundStyle(.secondary)
    }
}

private func rangeColor(_ r: MuscleStat.Range) -> Color {
    switch r {
    case .good: return .green
    case .low: return .orange
    case .high: return .red
    case .none: return .gray
    }
}

private func rangeText(_ r: MuscleStat.Range) -> String {
    switch r {
    case .good: return "in a good range"
    case .low: return "on the low side"
    case .high: return "very high"
    case .none: return "no recent sets"
    }
}

private struct MuscleRow: View {
    let stat: MuscleStat

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(rangeColor(stat.range)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(stat.muscle.label).font(.headline)
                Text("\(String(format: "%.0f", stat.weeklyAverage)) sets a week · last \(Format.daysAgo(stat.daysSince))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if let pct = stat.strengthChangePercent {
                Label("\(pct >= 0 ? "+" : "")\(String(format: "%.0f", pct))%", systemImage: pct >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline).foregroundStyle(pct >= 0 ? Color.green : Color.red)
            }
        }
    }
}

struct MuscleDetailView: View {
    @Environment(AppModel.self) private var model
    let stat: MuscleStat
    let unit: WeightUnit

    var body: some View {
        let points = stat.topLift.flatMap { Insights.liftHistory(model.logs)[$0] } ?? []

        List {
            Section("Volume") {
                LabeledContent("This week", value: "\(String(format: "%.1f", stat.setsThisWeek)) sets")
                LabeledContent("Weekly average (4 weeks)", value: "\(String(format: "%.1f", stat.weeklyAverage)) sets")
                LabeledContent("Last trained", value: Format.daysAgo(stat.daysSince))
                Label(rangeText(stat.range).capitalized, systemImage: "circle.fill").foregroundStyle(rangeColor(stat.range))
                Text("A common guide is about 8 to 20 hard sets a week per muscle. Helper muscles count half. This is a rough guide, not advice.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Strength") {
                if let top = stat.topLift {
                    LabeledContent("Main lift", value: top)
                    if points.count >= 2 { LiftChart(points: points, unit: unit) }
                    if let change = stat.strengthChangeKg, let pct = stat.strengthChangePercent {
                        LabeledContent("Estimated max, last 8 weeks", value: "\(change >= 0 ? "+" : "")\(Units.tidy(Units.fromKg(change, to: unit))) \(unit.rawValue) (\(String(format: "%.0f", pct))%)")
                    } else {
                        Text("Log this lift in two sessions to see a trend.").font(.footnote).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No weighted lift logged for this muscle yet.").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(stat.muscle.label)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { InsightsView() }.environment(AppModel.sample())
}
