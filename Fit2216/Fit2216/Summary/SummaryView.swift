import SwiftUI
import Fit2216Core

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @State private var logging: LoggingTarget?
    @State private var reviewing: LoggingTarget?

    var body: some View {
        let now = model.now
        let session = Summary.today(plan: model.plan, logs: model.logs, now)
        let streak = Summary.streak(plan: model.plan, logs: model.logs, now)
        let week = Summary.week(plan: model.plan, logs: model.logs, now)
        let todayLog = session.flatMap { s in model.logs.first { $0.date == Dates.localDate(now) && Plan.matches($0, s.day) } }
        let left = session.map { Summary.remaining(day: $0.day, log: todayLog) } ?? []
        let bodyCard = Summary.body(weights: model.weights, profile: model.profile, now)
        let best = Summary.recentBest(logs: model.logs, now)

        ScrollView {
            VStack(spacing: 16) {
                if let session {
                    TodayCard(session: session, streak: streak, left: left)
                } else {
                    ContentUnavailableView("No plan yet", systemImage: "calendar", description: Text("Add a plan in the Workout tab."))
                }
                WeekCard(week: week)
                BodyCard(summary: bodyCard, unit: model.profile.bodyUnit)
                if let best { BestCard(record: best, unit: model.profile.gymUnit) }
            }
            .padding()
        }
        .navigationTitle("Summary")
        .safeAreaInset(edge: .bottom) {
            StartBar(session: session) {
                guard let session else { return }
                if session.state == .finished { reviewing = LoggingTarget(day: session.day) } else { logging = LoggingTarget(day: session.day) }
            }
        }
        .fullScreenCover(item: $logging) { LoggingView(day: $0.day) }
        .sheet(item: $reviewing) { ReviewProgressView(day: $0.day) }
    }
}

private struct TodayCard: View {
    let session: TodaySession
    let streak: Int
    let left: [RemainingExercise]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.isToday ? "Today" : "Next up").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                    Text(session.day.name).font(.title2.bold())
                }
                Spacer()
                Label("\(streak)", systemImage: "flame.fill").foregroundStyle(.orange).font(.headline)
                    .accessibilityLabel("Workout streak \(streak)")
            }

            if !session.muscles.isEmpty {
                Text(session.muscles.map(\.label).joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
            }

            switch session.state {
            case .rest:
                Text("Rest day. Recovery is part of the plan.").font(.subheadline)
            case .skipped:
                Text("Skipped today.").font(.subheadline)
            default:
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: Double(session.loggedSets), total: Double(max(session.plannedSets, 1)))
                    Text("\(session.loggedSets) of \(session.plannedSets) sets done" + (session.state == .finished ? " · finished" : ""))
                        .font(.footnote).foregroundStyle(.secondary)
                    if !left.isEmpty && session.state != .finished {
                        Divider()
                        Text("Left to do").font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                        ForEach(left.prefix(4), id: \.name) { e in
                            HStack {
                                Text(e.name + (e.optional ? " (optional)" : "")).font(.subheadline)
                                Spacer()
                                Text("\(e.setsLeft) \(e.setsLeft == 1 ? "set" : "sets")").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        if left.count > 4 { Text("+ \(left.count - 4) more").font(.footnote).foregroundStyle(.secondary) }
                    }
                }
            }
        }
        .card()
    }
}

private struct WeekCard: View {
    let week: WeekSummary
    private static let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This week").font(.headline)
                Spacer()
                Text("\(week.done) of \(week.planned) workouts").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack {
                ForEach(week.days, id: \.date) { d in
                    VStack(spacing: 6) {
                        Text(Self.letters[d.weekday]).font(.caption).foregroundStyle(.secondary)
                        Circle()
                            .fill(color(d.state))
                            .frame(width: 28, height: 28)
                            .overlay { if d.isToday { Circle().stroke(Color.primary, lineWidth: 2) } }
                            .overlay { if !symbol(d.state).isEmpty { Image(systemName: symbol(d.state)).font(.caption.bold()).foregroundStyle(.white) } }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(d.day?.name ?? "No plan"), \(label(d.state))")
                }
            }
        }
        .card()
    }

    private func color(_ s: WeekDay.State) -> Color {
        switch s {
        case .done: return .green
        case .missed: return .red
        case .skipped: return .orange
        case .today: return .blue.opacity(0.35)
        case .upcoming: return .gray.opacity(0.35)
        case .rest, .none: return .gray.opacity(0.15)
        }
    }

    private func symbol(_ s: WeekDay.State) -> String {
        switch s {
        case .done: return "checkmark"
        case .missed: return "xmark"
        case .skipped: return "forward.fill"
        default: return ""
        }
    }

    private func label(_ s: WeekDay.State) -> String {
        switch s {
        case .done: return "done"
        case .missed: return "missed"
        case .skipped: return "skipped"
        case .today: return "today"
        case .upcoming: return "upcoming"
        case .rest, .none: return "rest"
        }
    }
}

private struct BodyCard: View {
    let summary: BodySummary?
    let unit: WeightUnit
    @State private var showWeighIn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Body weight").font(.headline)
                Spacer()
                Button("Log weight") { showWeighIn = true }.font(.subheadline.bold())
            }
            if let summary {
                Text(Format.weight(kg: summary.latestKg, unit: unit)).font(.title2.bold())
                Text("Logged \(Format.date(summary.latestDate))").font(.footnote).foregroundStyle(.secondary)
                if let pace = summary.perWeekKg {
                    let shown = Units.fromKg(pace, to: unit)
                    Text("\(shown >= 0 ? "+" : "")\(String(format: "%.1f", shown)) \(unit.rawValue) a week over the last month").font(.subheadline)
                } else {
                    Text("Log a few more weigh-ins to see your trend.").font(.subheadline).foregroundStyle(.secondary)
                }
                if let line = projectionLine(summary) { Text(line).font(.subheadline).foregroundStyle(.secondary) }
            } else {
                Text("No weigh-ins yet.").font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .card()
        .sheet(isPresented: $showWeighIn) { WeighInSheet() }
    }

    private func projectionLine(_ s: BodySummary) -> String? {
        guard let p = s.projection, let target = s.baselineKg else { return nil }
        let goal = Format.weight(kg: target, unit: unit)
        switch p.state {
        case .on: return p.arrival.map { "At this pace you reach \(goal) around \($0.formatted(date: .abbreviated, time: .omitted))." }
        case .reached: return "You are at your target of \(goal)."
        case .away: return "Moving away from your target of \(goal)."
        case .flat: return "Holding steady; your target is \(goal)."
        case .far: return "More than two years to \(goal) at this pace."
        }
    }
}

private struct BestCard: View {
    let record: PersonalRecord
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent best").font(.headline)
            Text(record.name).font(.title3.bold())
            Text("\(Format.weight(kg: record.weight, unit: unit)) × \(Int(record.reps)) on \(Format.date(record.date))").font(.subheadline).foregroundStyle(.secondary)
        }
        .card()
    }
}

/// The Start button, pinned above the tab bar so it never scrolls away.
private struct StartBar: View {
    let session: TodaySession?
    let action: () -> Void

    private var title: String {
        switch session?.state {
        case .inProgress: return "Continue"
        case .finished: return "Review progress"
        case .rest: return "Rest day"
        case .skipped: return "Skipped"
        default: return "Start"
        }
    }

    var body: some View {
        Button(action: action) { Text(title).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6) }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(session == nil || session?.state == .rest || session?.state == .skipped)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
    }
}

#Preview {
    NavigationStack { SummaryView() }.environment(AppModel.sample())
}
