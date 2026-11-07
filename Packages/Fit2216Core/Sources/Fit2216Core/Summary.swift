import Foundation

public struct TodaySession: Equatable, Sendable {
    public enum State: Sendable { case rest, notStarted, inProgress, finished, skipped }
    public var day: TemplateDay
    public var state: State
    public var muscles: [Muscle]      // hardest-worked first
    public var plannedSets: Int
    public var loggedSets: Int
    public var isToday: Bool          // false when today has no entry and this is the next planned day
}

/// The line that answers "what should I do now?" for the Summary hero card.
public struct Guidance: Equatable, Sendable {
    public var headline: String
    public var detail: String
}

/// What the Summary screen shows: today's session card and the workout streak.
public enum Summary {
    /// Today's day if the plan has one, else the day `Plan.pick` offers (a catch-up or the next planned day).
    public static func today(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> TodaySession? {
        let weekday = Dates.weekday(now, cal)
        let todays = plan.first { $0.day == weekday }
        guard let day = todays ?? Plan.pick(plan, logs, now, cal)?.day else { return nil }
        let date = Dates.localDate(now, cal)
        let log = logs.first { $0.date == date && Plan.matches($0, day) }
        let rest = day.type == .rest || day.exercises.isEmpty
        let state: TodaySession.State
        if rest { state = .rest }
        else if log?.skipped == true { state = .skipped }
        else if let log, Plan.isFinished(log, day) || log.done == true { state = .finished }
        else if let log, Plan.loggedSets(log) > 0 { state = .inProgress }
        else { state = .notStarted }
        let loads = Muscles.forDay(day)
        let muscles = loads.sorted { a, b in (a.value == .primary ? 0 : 1, a.key.rawValue) < (b.value == .primary ? 0 : 1, b.key.rawValue) }.map(\.key)
        return TodaySession(day: day, state: state, muscles: muscles, plannedSets: Plan.plannedSets(day), loggedSets: log.map(Plan.loggedSets) ?? 0, isToday: todays != nil)
    }

    /// The log that counts for `day` on `date`: one dated that day, else one for the same session done on another day of that
    /// Monday-to-Sunday week (a missed Monday done on Friday, Friday's session done early on Thursday). A finished log beats a
    /// skipped one, so a skipped day that was later done counts as done. A session from another week never counts.
    static func weekLog(for day: TemplateDay, on date: String, in logs: [WorkoutLog], _ cal: Calendar) -> WorkoutLog? {
        guard let d = Dates.parse(date, cal) else { return logs.first { $0.date == date && Plan.matches($0, day) } }
        let dates = Dates.weekDates(d, cal).map { Dates.localDate($0, cal) }
        guard let first = dates.first, let last = dates.last else { return nil }
        let candidates = logs.filter { Plan.matches($0, day) && $0.date >= first && $0.date <= last }
        let finished = candidates.filter { $0.skipped != true && Plan.isComplete($0, day) }
        if let best = finished.first(where: { $0.date == date }) ?? finished.first { return best }
        return candidates.first(where: { $0.date == date }) ?? candidates.first
    }

    /// The streak shown on Summary: how many weeks (Monday to Sunday) in a row you did every planned workout, on any days and in
    /// any order, so a week shifted by a day still counts. This week adds one as soon as its last workout is done and, while it is
    /// still going, neither adds nor breaks anything. A finished week with a workout missing, or only skipped, resets it to 0.
    /// A week counts when its plan days all show as done on the week strip (`weekLog` and `Plan.isComplete`).
    /// Weeks are judged against the current plan.
    public static func weekStreak(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current, maxWeeks: Int = 104) -> Int {
        let training = plan.filter { $0.type != .rest && !$0.exercises.isEmpty }
        guard !training.isEmpty else { return 0 }
        func complete(weekOf monday: Date) -> Bool {
            let dates = Dates.weekDates(monday, cal)
            return training.allSatisfy { day in
                let date = Dates.localDate(dates[Dates.mondayIndex(day.day)], cal)
                guard let log = weekLog(for: day, on: date, in: logs, cal) else { return false }
                return log.skipped != true && Plan.isComplete(log, day)
            }
        }
        let thisMonday = Dates.monday(of: now, cal)
        var count = complete(weekOf: thisMonday) ? 1 : 0
        for back in 1...max(1, maxWeeks) {
            guard let monday = cal.date(byAdding: .day, value: -7 * back, to: thisMonday), complete(weekOf: monday) else { break }
            count += 1
        }
        return count
    }

    /// Consecutive scheduled training days handled, counting back from today. Rest days and days without a plan entry are skipped over;
    /// a deliberately skipped day neither counts nor breaks the streak; today only counts once it is handled and never breaks the streak.
    public static func streak(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current, maxDays: Int = 400) -> Int {
        var count = 0
        let today = Dates.localDate(now, cal)
        for back in 0..<maxDays {
            guard let d = cal.date(byAdding: .day, value: -back, to: now) else { break }
            guard let day = plan.first(where: { $0.day == Dates.weekday(d, cal) }), day.type != .rest, !day.exercises.isEmpty else { continue }
            let date = Dates.localDate(d, cal)
            let log = weekLog(for: day, on: date, in: logs, cal)
            if log?.skipped == true { continue }
            if let log, Plan.isComplete(log, day) { count += 1; continue }
            if date == today { continue } // not done yet, but the day is not over
            break
        }
        return count
    }
}

// MARK: - Week strip, what is left today, body card, recent best

public struct WeekDay: Equatable, Sendable {
    public enum State: Sendable { case none, rest, done, skipped, missed, today, upcoming }
    public var date: String
    public var weekday: Int          // 0 = Sunday
    public var day: TemplateDay?
    public var state: State
    public var isToday: Bool
}

public struct WeekSummary: Equatable, Sendable {
    public var days: [WeekDay]       // Monday to Sunday
    public var done: Int             // training days handled
    public var planned: Int          // training days in the plan
}

public struct RemainingExercise: Equatable, Sendable {
    public var name: String
    public var setsLeft: Int
    public var optional: Bool
}

public struct BodySummary: Equatable, Sendable {
    public var latestKg: Double
    public var latestDate: String
    public var averageKg: Double         // trailing 7-day average at the latest entry
    public var perWeekKg: Double?        // 4-week trend, nil without enough data
    public var baselineKg: Double?
    public var projection: Projection?
}

extension Summary {
    /// Monday to Sunday: which days are done, missed, today or still ahead.
    public static func week(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> WeekSummary {
        let today = Dates.localDate(now, cal)
        var days: [WeekDay] = []
        var done = 0, planned = 0
        for d in Dates.weekDates(now, cal) {
            let date = Dates.localDate(d, cal), weekday = Dates.weekday(d, cal)
            let day = plan.first { $0.day == weekday }
            var state: WeekDay.State
            if let day, day.type != .rest, !day.exercises.isEmpty {
                planned += 1
                let log = weekLog(for: day, on: date, in: logs, cal)
                if log?.skipped == true { state = .skipped }
                else if let log, Plan.isComplete(log, day) { state = .done; done += 1 }
                else if date == today { state = .today }
                else if date < today { state = .missed }
                else { state = .upcoming }
            } else {
                state = day == nil ? .none : .rest
            }
            days.append(WeekDay(date: date, weekday: weekday, day: day, state: state, isToday: date == today))
        }
        return WeekSummary(days: days, done: done, planned: planned)
    }

    /// The exercises of `day` that still have sets to log, required ones first.
    public static func remaining(day: TemplateDay, log: WorkoutLog?) -> [RemainingExercise] {
        let all = day.exercises.compactMap { e -> RemainingExercise? in
            let logged = (log?.sets[e.name] ?? []).filter { Plan.filled($0) }.count
            let left = max(0, e.sets - logged)
            guard left > 0 else { return nil }
            return RemainingExercise(name: log.map { Plan.effectiveName($0, e.name) } ?? e.name, setsLeft: left, optional: e.optional == true)
        }
        return all.filter { !$0.optional } + all.filter { $0.optional }
    }

    /// Weight card: latest weigh-in, smoothed weight, 4-week pace and where it leads, measured against your target (or a healthy weight for your height).
    public static func body(weights: [WeightEntry], profile: Profile, _ now: Date, _ cal: Calendar = .current) -> BodySummary? {
        let asc = weights.sorted { $0.date < $1.date }
        guard let latest = asc.last, let avg = Insights.movingAverage(asc, days: 7, cal).last else { return nil }
        let trend = Insights.weightTrend(asc, now, cal)?.perWeek
        let baseline = Insights.baselineWeight(heightCm: profile.heightCm, targetWeightKg: profile.targetWeightKg)?.kg
        var projection: Projection?
        if let trend, let baseline { projection = Insights.projectToBaseline(currentKg: avg.kg, perWeekKg: trend, baselineKg: baseline, now, cal) }
        return BodySummary(latestKg: latest.kg, latestDate: latest.date, averageKg: avg.kg, perWeekKg: trend, baselineKg: baseline, projection: projection)
    }

    /// The newest personal record in the last two weeks, if any.
    public static func recentBest(logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> PersonalRecord? {
        Insights.recentPRs(Insights.liftHistory(logs), now, days: 14, limit: 1, cal).first
    }

    /// What to do now, from today's state: start, continue, review, rest, or what comes next.
    public static func guidance(_ s: TodaySession, nextName: String? = nil) -> Guidance {
        let sets = s.plannedSets, done = s.loggedSets, left = max(0, sets - done)
        func sets_(_ n: Int) -> String { n == 1 ? "1 set" : "\(n) sets" }
        switch s.state {
        case .rest:
            return Guidance(headline: "Rest day", detail: nextName.map { "Recovery is part of the plan. Next: \($0)." } ?? "Recovery is part of the plan.")
        case .skipped:
            return Guidance(headline: "Skipped today", detail: "No problem. Pick it up on the next planned day.")
        case .finished:
            return Guidance(headline: "Done for today", detail: nextName.map { "\(sets_(done)) logged. Next: \($0)." } ?? "\(sets_(done)) logged.")
        case .inProgress:
            return Guidance(headline: "Keep going", detail: "\(sets_(left)) left in \(s.day.name).")
        case .notStarted:
            if s.isToday { return Guidance(headline: "Ready when you are", detail: "\(sets_(sets)) across \(s.day.exercises.count) exercises.") }
            return Guidance(headline: "Next up", detail: "\(s.day.name), \(sets_(sets)).")
        }
    }
}
