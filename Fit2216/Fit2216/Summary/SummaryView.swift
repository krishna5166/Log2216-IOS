import SwiftUI
import Fit2216Core

struct SummaryView: View {
    @Environment(AppModel.self) private var model
    @State private var logging: LoggingTarget?
    @State private var reviewing: LoggingTarget?
    @State private var tidying = false

    var body: some View {
        let now = model.now
        let session = Summary.today(plan: model.plan, logs: model.logs, now)
        let streak = Summary.streak(plan: model.plan, logs: model.logs, now)
        let week = Summary.week(plan: model.plan, logs: model.logs, now)
        let todayLog = session.flatMap { s in model.logs.first { $0.date == Dates.localDate(now) && Plan.matches($0, s.day) } }
        let left = session.map { Summary.remaining(day: $0.day, log: todayLog) } ?? []
        let bodyCard = Summary.body(weights: model.weights, profile: model.profile, now)
        let best = Summary.recentBest(logs: model.logs, now)
        let next = session.flatMap { $0.state == .finished ? Plan.nextUp(model.plan, model.logs, now, afterDay: $0.day.day) : nil }

        ScrollView {
            VStack(spacing: 14) {
                if let session {
                    HeroCard(session: session, streak: streak, week: week)
                    if session.state != .rest && session.state != .skipped && (!left.isEmpty || next != nil) {
                        UpNextCard(session: session, left: left, next: next)
                    }
                } else {
                    ContentUnavailableView("No plan yet", systemImage: "calendar", description: Text("Add a plan in the Workout tab."))
                }
                if model.canLog {
                    let drift = ExerciseNames.drift(plan: model.plan, logs: model.logs)
                    if !drift.isEmpty { DriftCard(count: drift.count) { tidying = true } }
                }
                WeekCard(week: week)
                BodyCard(summary: bodyCard, unit: model.profile.bodyUnit)
                if let best { BestCard(record: best, unit: model.profile.gymUnit) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .navigationTitle("Summary")
        .safeAreaInset(edge: .bottom) {
            StartBar(session: session, ready: model.canLog) {
                guard let session else { return }
                if session.state == .finished { reviewing = LoggingTarget(day: session.day) } else { logging = LoggingTarget(day: session.day) }
            }
        }
        .fullScreenCover(item: $logging) { LoggingView(day: $0.day) }
        .sheet(isPresented: $tidying) { NavigationStack { TidyNamesView() } }
        .sheet(item: $reviewing) { target in
            ReviewProgressView(day: target.day) {
                reviewing = nil
                Task { try? await Task.sleep(for: .milliseconds(450)); logging = target } // after the sheet has closed
            }
        }
    }
}

/// The top card, like Fitness's Activity Rings: two rings (sets today, workouts this week) and big coloured numbers.
private struct HeroCard: View {
    let session: TodaySession
    let streak: Int
    let week: WeekSummary

    private var setsProgress: Double { session.plannedSets > 0 ? Double(session.loggedSets) / Double(session.plannedSets) : 0 }
    private var weekProgress: Double { week.planned > 0 ? Double(week.done) / Double(week.planned) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.isToday ? "TODAY" : "NEXT UP").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text(session.day.name).font(.system(size: 28, weight: .bold, design: .rounded))
            }

            HStack(spacing: 22) {
                ZStack {
                    Ring(progress: setsProgress, color: Theme.pink, size: 146)
                    Ring(progress: weekProgress, color: Theme.lime, size: 146 - 42)
                }
                VStack(alignment: .leading, spacing: 10) {
                    metric("Sets", "\(session.loggedSets)/\(session.plannedSets)", "sets", Theme.pink)
                    metric("This week", "\(week.done)/\(week.planned)", "wks", Theme.lime)
                    metric("Streak", "\(streak)", streak == 1 ? "day" : "days", .orange)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            switch session.state {
            case .rest: Text("Rest day. Recovery is part of the plan.").font(.subheadline)
            case .skipped: Text("Skipped today.").font(.subheadline)
            case .finished: Label("Finished", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.lime)
            default: EmptyView()
            }

            if !session.muscles.isEmpty {
                Text(session.muscles.map(\.label).joined(separator: " · ")).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func metric(_ label: String, _ value: String, _ unit: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.subheadline)
            BigValue(value: value, unit: unit, color: color, size: 28)
        }
    }
}

/// What is left today and what comes after.
private struct UpNextCard: View {
    let session: TodaySession
    let left: [RemainingExercise]
    let next: TemplateDay?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !left.isEmpty && session.state != .finished {
                Text("Left to do").font(.title3.weight(.semibold))
                ForEach(left.prefix(4), id: \.name) { e in
                    HStack {
                        Text(e.name + (e.optional ? " (optional)" : "")).font(.body)
                        Spacer()
                        Text("\(e.setsLeft) \(e.setsLeft == 1 ? "set" : "sets")").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                if left.count > 4 { Text("+ \(left.count - 4) more").font(.footnote).foregroundStyle(.secondary) }
            }
            if let next {
                if !left.isEmpty && session.state != .finished { Divider() }
                Text("NEXT").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                Text("\(next.name) · \(Calendar.current.shortWeekdaySymbols[next.day])").font(.body)
            }
        }
        .card()
    }
}

/// Shown when one exercise is saved under several names (the drift check), so trends do not split silently.
private struct DriftCard: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(count) exercise\(count == 1 ? "" : "s") saved under more than one name").font(.subheadline.weight(.semibold))
                    Text("Tap to tidy so trends and bests stay together.").font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
            }
            .card()
        }
        .buttonStyle(.plain)
    }
}

private struct WeekCard: View {
    let week: WeekSummary
    private static let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This week").font(.title3.weight(.semibold))
                Spacer()
                BigValue(value: "\(week.done)/\(week.planned)", unit: "workouts", color: Theme.lime, size: 22)
            }
            HStack {
                ForEach(week.days, id: \.date) { d in
                    VStack(spacing: 8) {
                        Text(Self.letters[d.weekday]).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Circle()
                            .fill(color(d.state))
                            .frame(width: 34, height: 34)
                            .overlay { if d.isToday { Circle().stroke(Theme.lime, lineWidth: 2.5).padding(-4) } }
                            .overlay { if !symbol(d.state).isEmpty { Image(systemName: symbol(d.state)).font(.caption.weight(.heavy)).foregroundStyle(d.state == .done ? Color.black : Color.white) } }
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
        case .done: return Theme.lime
        case .missed: return Theme.pink.opacity(0.85)
        case .skipped: return .orange.opacity(0.85)
        case .today: return Color.white.opacity(0.22)
        case .upcoming: return Color.white.opacity(0.14)
        case .rest, .none: return Color.white.opacity(0.06)
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
                Text("Body weight").font(.title3.weight(.semibold))
                Spacer()
                Button { showWeighIn = true } label: {
                    Text("Log weight").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            if let summary {
                BigValue(value: Units.tidy(Units.fromKg(summary.latestKg, to: unit)), unit: unit.rawValue, color: Theme.cyan, size: 44)
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
            Text("Recent best").font(.title3.weight(.semibold))
            Text(record.name).font(.subheadline).foregroundStyle(.secondary)
            BigValue(value: "\(Units.tidy(Units.fromKg(record.weight, to: unit))) × \(Int(record.reps))", unit: unit.rawValue, color: Theme.lime, size: 40)
            Text("on \(Format.date(record.date))").font(.footnote).foregroundStyle(.secondary)
        }
        .card()
    }
}

/// The Start button, pinned above the tab bar so it never scrolls away.
private struct StartBar: View {
    let session: TodaySession?
    let ready: Bool
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

    private var enabled: Bool { ready && session != nil && session?.state != .rest && session?.state != .skipped }

    var body: some View {
        Button(action: action) {
            Text(title).font(.title3.bold())
                .frame(maxWidth: .infinity).frame(height: 58)
                .foregroundStyle(.black)
                .background(Theme.lime, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

#Preview {
    NavigationStack { SummaryView() }.environment(AppModel.sample())
}
