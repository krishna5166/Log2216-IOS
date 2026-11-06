import SwiftUI
import Fit2216Core

/// Strength and volume by body part, not by workout. Each muscle opens its own detail.
struct InsightsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let now = model.now
        let stats = MuscleInsights.stats(plan: model.plan, logs: model.logs, now)
        let flags = MuscleInsights.balance(stats: stats, plan: model.plan)

        List {
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
        }
        .navigationTitle("Insights")
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
    let stat: MuscleStat
    let unit: WeightUnit

    var body: some View {
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
