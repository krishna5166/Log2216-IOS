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

    /// Consecutive scheduled training days handled, counting back from today. Rest days and days without a plan entry are skipped over;
    /// a deliberately skipped day neither counts nor breaks the streak; today only counts once it is handled and never breaks the streak.
    public static func streak(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current, maxDays: Int = 400) -> Int {
        var count = 0
        let today = Dates.localDate(now, cal)
        for back in 0..<maxDays {
            guard let d = cal.date(byAdding: .day, value: -back, to: now) else { break }
            guard let day = plan.first(where: { $0.day == Dates.weekday(d, cal) }), day.type != .rest, !day.exercises.isEmpty else { continue }
            let date = Dates.localDate(d, cal)
            let log = logs.first { $0.date == date && Plan.matches($0, day) }
            if log?.skipped == true { continue }
            if let log, Plan.isComplete(log, day) { count += 1; continue }
            if date == today { continue } // not done yet, but the day is not over
            break
        }
        return count
    }
}
