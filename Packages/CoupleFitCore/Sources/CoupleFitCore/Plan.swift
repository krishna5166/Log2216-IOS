import Foundation

public struct PickedWorkout: Equatable, Sendable {
    public var day: TemplateDay
    public var catchUp: Bool
    public var allDone: Bool
}

/// Which workout is due, what counts as done or missed, and the small set-by-set helpers. A port of app/src/lib/plan.ts.
public enum Plan {
    /// Monday-first ordering for display.
    public static func sort(_ plan: [TemplateDay]) -> [TemplateDay] {
        plan.sorted { Dates.mondayIndex($0.day) < Dates.mondayIndex($1.day) }
    }

    /// Numbers inside a rep range like "4–6", "10–15/side" or "8".
    private static func numbers(in reps: String) -> [Int] {
        var out: [Int] = [], cur = ""
        for ch in reps {
            if ch.isASCII, ch.isNumber { cur.append(ch) } else if !cur.isEmpty { out.append(Int(cur) ?? 0); cur = "" }
        }
        if !cur.isEmpty { out.append(Int(cur) ?? 0) }
        return out
    }
    public static func topReps(_ reps: String) -> Int { numbers(in: reps).last ?? 0 }
    public static func bottomReps(_ reps: String) -> Int { numbers(in: reps).first ?? 0 }

    public static func effectiveName(_ log: WorkoutLog, _ original: String) -> String {
        if let swapped = log.swaps?[original], !swapped.isEmpty { return swapped }
        return original
    }

    public static func filled(_ s: SetLog?) -> Bool { s != nil && s!.reps != "" }

    public static func matches(_ l: WorkoutLog, _ d: TemplateDay) -> Bool {
        if let i = l.dayIndex { return i == d.day }
        return l.dayName == d.name
    }

    public static func plannedSets(_ d: TemplateDay) -> Int { d.exercises.filter { $0.optional != true }.reduce(0) { $0 + $1.sets } }
    public static func loggedSets(_ l: WorkoutLog) -> Int { l.sets.values.reduce(0) { $0 + $1.filter { filled($0) }.count } }

    /// Handled when finished, skipped, or at least half its sets are logged.
    public static func isComplete(_ l: WorkoutLog, _ d: TemplateDay) -> Bool {
        if l.done == true || l.skipped == true { return true }
        let total = plannedSets(d)
        return total > 0 && loggedSets(l) >= Int((Double(total) / 2).rounded(.up))
    }

    /// Truly finished: marked done, or every non-optional exercise has all its sets logged (stricter than `isComplete`).
    public static func isFinished(_ l: WorkoutLog, _ d: TemplateDay) -> Bool {
        if l.skipped == true { return false }
        if l.done == true { return true }
        let required = d.exercises.filter { $0.optional != true }
        return !required.isEmpty && required.allSatisfy { e in (l.sets[e.name] ?? []).filter { filled($0) }.count >= e.sets }
    }

    public static func doneThisWeek(_ d: TemplateDay, _ logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> Bool {
        let start = Dates.weekStart(now, cal)
        return logs.contains { $0.date >= start && matches($0, d) && isComplete($0, d) }
    }

    private static func isTraining(_ d: TemplateDay) -> Bool { d.type != .rest && !d.exercises.isEmpty }

    /// A workout started today that is neither finished nor skipped (kept on screen rather than jumping to the next day).
    public static func inProgressToday(_ plan: [TemplateDay], _ logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> TemplateDay? {
        let today = Dates.localDate(now, cal)
        return sort(plan).first { d in
            guard isTraining(d), let l = logs.first(where: { $0.date == today && matches($0, d) }) else { return false }
            return l.done != true && l.skipped != true && loggedSets(l) > 0 && !isFinished(l, d)
        }
    }

    /// The workout to open: the one in progress today, else the earliest unhandled training day this week up to today (a catch-up),
    /// else today's day if the plan has one, else the next planned day. The plan may have any days.
    public static func pick(_ plan: [TemplateDay], _ logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> PickedWorkout? {
        if let open = inProgressToday(plan, logs, now, cal) { return PickedWorkout(day: open, catchUp: open.day != Dates.weekday(now, cal), allDone: false) }
        let sorted = sort(plan)
        guard !sorted.isEmpty else { return nil }
        let today = Dates.weekday(now, cal)
        var todayPos = -1
        for (i, d) in sorted.enumerated() where Dates.mondayIndex(d.day) <= Dates.mondayIndex(today) { todayPos = i }
        if todayPos >= 0 {
            for i in 0...todayPos {
                let d = sorted[i]
                if !isTraining(d) { continue }
                if !doneThisWeek(d, logs, now, cal) { return PickedWorkout(day: d, catchUp: d.day != today, allDone: false) }
            }
        }
        let hasToday = todayPos >= 0 && sorted[todayPos].day == today
        let day = hasToday ? sorted[todayPos] : (todayPos + 1 < sorted.count ? sorted[todayPos + 1] : sorted[0])
        return PickedWorkout(day: day, catchUp: false, allDone: true)
    }

    /// Training days earlier in this week that are not done or skipped, Monday first.
    public static func missedDays(_ plan: [TemplateDay], _ logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> [TemplateDay] {
        let dates = Dates.weekDates(now, cal)
        let today = Dates.localDate(now, cal)
        return sort(plan).filter { d in
            isTraining(d) && Dates.localDate(dates[Dates.mondayIndex(d.day)], cal) < today && !doneThisWeek(d, logs, now, cal)
        }
    }

    /// The workout to point at after `afterDay`: the next training day this week not yet handled, else the week's first. Nil with no training days.
    public static func nextUp(_ plan: [TemplateDay], _ logs: [WorkoutLog], _ now: Date, afterDay: Int, _ cal: Calendar = .current) -> TemplateDay? {
        let training = sort(plan).filter(isTraining)
        guard !training.isEmpty else { return nil }
        let later = training.filter { Dates.mondayIndex($0.day) > Dates.mondayIndex(afterDay) && !doneThisWeek($0, logs, now, cal) }
        return later.first ?? training[0]
    }

    // MARK: Per-exercise helpers

    /// The last `n` earlier sessions (newest first) in which `name` was performed, weights shown in `unit`.
    public static func recentSessions(_ logs: [WorkoutLog], name: String, before date: String, unit: WeightUnit = .kg, count n: Int = 3) -> [(date: String, sets: [SetLog])] {
        var out: [(date: String, sets: [SetLog])] = []
        for log in logs.filter({ $0.date < date }).sorted(by: { $0.date > $1.date }) {
            for (orig, sets) in log.sets.sorted(by: { $0.key < $1.key }) where effectiveName(log, orig) == name {
                let done = sets.filter { filled($0) }.map { SetLog(weight: Units.convertWeightString($0.weight, from: Units.logUnit(log), to: unit), reps: $0.reps) }
                if !done.isEmpty { out.append((log.date, done)); break }
            }
            if out.count >= n { break }
        }
        return out
    }

    /// True when every prescribed set hit the top of the rep range (suggest more weight).
    public static func readyToIncrease(_ ex: TemplateExercise, _ sets: [SetLog]?) -> Bool {
        guard let sets else { return false }
        let top = topReps(ex.reps)
        let done = sets.filter { filled($0) }
        return top > 0 && done.count >= ex.sets && done.allSatisfy { (Int($0.reps) ?? 0) >= top && $0.weight != "" }
    }

    /// Rest between sets: heavy low-rep work longest, Devil Press and high-rep accessories shortest.
    public static func restSeconds(_ e: TemplateExercise) -> Int {
        if let r = e.restSec, r > 0 { return r }
        if e.name.range(of: "devil", options: .caseInsensitive) != nil { return 90 }
        let top = topReps(e.reps)
        return top <= 6 ? 180 : top <= 10 ? 120 : 90
    }

    public static func clock(_ secs: Double) -> String {
        let s = max(0, Int(secs.rounded(.up)))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    /// Adds `delta` to a typed number (falling back to `fallback` when empty); never below `min`; no float noise.
    public static func step(_ current: String, fallback: Double, delta: Double, min lowest: Double = 0) -> String {
        let base = (current != "" ? Double(current) : nil) ?? fallback
        let v = max(lowest, ((base + delta) * 100).rounded() / 100)
        return v == v.rounded() ? String(Int(v)) : String(v)
    }

    /// What a set most likely is: the previous set just done, else the same set last time (weight bumped one step when ready).
    public static func suggestSet(current: [SetLog]?, index i: Int, last: [SetLog]?, ready: Bool, step stepSize: Double) -> SetLog? {
        if i > 0, let prev = current?[safe: i - 1], filled(prev) { return SetLog(weight: prev.weight, reps: prev.reps) }
        guard let lastSet = last?[safe: i] ?? last?.first, filled(lastSet) else { return nil }
        return SetLog(weight: ready && lastSet.weight != "" ? step(lastSet.weight, fallback: 0, delta: stepSize) : lastSet.weight, reps: lastSet.reps)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
