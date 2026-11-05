import Foundation

public enum Goal: String, Codable, Sendable { case lose, maintain, gain }

public struct LiftPoint: Equatable, Sendable {
    public var date: String
    public var e1rm: Double   // always kg
    public var weight: Double // always kg
    public var reps: Double
}

public struct WeekStat: Equatable, Sendable {
    public var start: String
    public var workouts: Int
    public var volume: Double // kg x reps
}

public struct PersonalRecord: Equatable, Sendable { public var name: String; public var date: String; public var weight: Double; public var reps: Double }
public struct Highlight: Equatable, Sendable { public var lift: String; public var gainKg: Double; public var since: String }

public struct BaselineSegment: Equatable, Sendable {
    public struct Point: Equatable, Sendable { public var t: Double; public var v: Double; public init(t: Double, v: Double) { self.t = t; self.v = v } }
    public var above: Bool
    public var pts: [Point]
}

public enum Tone: Sendable { case good, bad }

public struct Projection: Equatable, Sendable {
    public enum State: Sendable { case on, reached, away, flat, far }
    public var state: State
    public var arrival: Date?
    public var weeks: Double?
}

/// Strength and weight analytics. A port of app/src/lib/insights.ts (and `baselineWeight` from nutrition.ts).
public enum Insights {
    /// Like JavaScript's parseFloat: the leading number, else 0.
    static func num(_ s: String) -> Double {
        var scanner = Scanner(string: s)
        scanner.charactersToBeSkipped = .whitespaces
        guard let v = scanner.scanDouble(), v.isFinite else { return 0 }
        return v
    }

    /// Epley estimated one-rep max; reps above 12 are treated as 12 (the estimate gets unreliable).
    public static func e1rm(weight: Double, reps: Double) -> Double { weight > 0 && reps > 0 ? weight * (1 + min(reps, 12) / 30) : 0 }

    /// Best set per exercise per day (swapped exercises count under the name actually done). Weights and 1RM are kg.
    public static func liftHistory(_ logs: [WorkoutLog]) -> [String: [LiftPoint]] {
        var byLift: [String: [String: LiftPoint]] = [:]
        for log in logs {
            for (orig, sets) in log.sets {
                let name = Plan.effectiveName(log, orig)
                for s in sets {
                    let w = Units.toKg(num(s.weight), from: Units.logUnit(log)), r = num(s.reps), est = e1rm(weight: w, reps: r)
                    if est <= 0 { continue }
                    if let cur = byLift[name]?[log.date], est <= cur.e1rm { continue }
                    byLift[name, default: [:]][log.date] = LiftPoint(date: log.date, e1rm: est, weight: w, reps: r)
                }
            }
        }
        return byLift.mapValues { $0.values.sorted { $0.date < $1.date } }
    }

    /// How many weekly bars to show: from the week of the earliest log (at most `max`), or just this week with no logs.
    public static func chartWeeks(_ logs: [WorkoutLog], _ now: Date, max cap: Int = 8, _ cal: Calendar = .current) -> Int {
        guard let earliest = logs.map(\.date).min(), let first = Dates.parse(earliest, cal) else { return 1 }
        let days = Dates.daysBetween(Dates.monday(of: first, cal), Dates.monday(of: now, cal), cal)
        return Swift.max(1, Swift.min(cap, Int((Double(days) / 7).rounded()) + 1))
    }

    /// Finished workouts and total volume (kg x reps) for each of the last `weeks` weeks, oldest first.
    public static func weeklyStats(_ logs: [WorkoutLog], plan: [TemplateDay], _ now: Date, weeks: Int = 8, _ cal: Calendar = .current) -> [WeekStat] {
        let thisMonday = Dates.localDate(Dates.monday(of: now, cal), cal)
        var stats = (0..<weeks).map { i in WeekStat(start: Dates.addDays(thisMonday, -7 * (weeks - 1 - i), cal), workouts: 0, volume: 0) }
        for l in logs {
            guard let idx = stats.firstIndex(where: { l.date >= $0.start && l.date < Dates.addDays($0.start, 7, cal) }) else { continue }
            stats[idx].volume += l.sets.values.joined().reduce(0) { $0 + Units.toKg(num($1.weight), from: Units.logUnit(l)) * num($1.reps) }
            let day = l.template ?? plan.first { l.dayIndex != nil ? $0.day == l.dayIndex : $0.name == l.dayName }
            let complete = day.map { Plan.isComplete(l, $0) } ?? (l.done == true)
            if l.skipped != true && complete { stats[idx].workouts += 1 }
        }
        return stats
    }

    /// Trailing average over the previous `days` days (inclusive) for each entry; entries sorted oldest first.
    public static func movingAverage(_ entries: [WeightEntry], days: Int = 7, _ cal: Calendar = .current) -> [WeightEntry] {
        entries.map { e in
            let from = Dates.addDays(e.date, -(days - 1), cal)
            let window = entries.filter { $0.date >= from && $0.date <= e.date }
            return WeightEntry(date: e.date, kg: window.reduce(0) { $0 + $1.kg } / Double(window.count))
        }
    }

    /// kg per week over the last 4 weeks (least-squares slope); nil when there is not enough data.
    public static func weightTrend(_ entries: [WeightEntry], _ now: Date, _ cal: Calendar = .current) -> (perWeek: Double, points: Int)? {
        let from = Dates.localDate(cal.date(byAdding: .day, value: -27, to: now) ?? now, cal)
        let pts = entries.filter { $0.date >= from }
        guard pts.count >= 3, let t0 = Dates.parse(pts[0].date, cal) else { return nil }
        let xs = pts.map { Double(Dates.daysBetween(t0, Dates.parse($0.date, cal) ?? t0, cal)) }
        guard let last = xs.last, last >= 7 else { return nil }
        let mx = xs.reduce(0, +) / Double(xs.count)
        let my = pts.reduce(0) { $0 + $1.kg } / Double(pts.count)
        let sxx = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx != 0 else { return nil }
        var sxy = 0.0
        for (i, x) in xs.enumerated() { sxy += (x - mx) * (pts[i].kg - my) }
        return (sxy / sxx * 7, pts.count)
    }

    /// Latest new personal record per lift within the last `days` days (beat every earlier estimated 1RM), newest first.
    public static func recentPRs(_ history: [String: [LiftPoint]], _ now: Date, days: Int = 14, limit: Int = 6, _ cal: Calendar = .current) -> [PersonalRecord] {
        let cutoff = Dates.localDate(cal.date(byAdding: .day, value: -(days - 1), to: now) ?? now, cal)
        var prs: [PersonalRecord] = []
        for (name, pts) in history {
            var best = 0.0
            var latest: PersonalRecord?
            for (i, p) in pts.enumerated() {
                if i > 0 && p.e1rm > best && p.date >= cutoff { latest = PersonalRecord(name: name, date: p.date, weight: p.weight, reps: p.reps) }
                best = Swift.max(best, p.e1rm)
            }
            if let latest { prs.append(latest) }
        }
        return Array(prs.sorted { $0.date == $1.date ? $0.name < $1.name : $0.date > $1.date }.prefix(limit))
    }

    /// Finished workouts vs planned training days this week.
    public static func weekCounts(_ plan: [TemplateDay], _ logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> (done: Int, planned: Int) {
        let training = plan.filter { $0.type != .rest && !$0.exercises.isEmpty }
        return (training.filter { Plan.doneThisWeek($0, logs, now, cal) }.count, training.count)
    }

    /// The lift whose estimated 1RM rose most between the first and latest session in the last 8 weeks (at least +1 kg, 2+ sessions).
    public static func liftHighlight(_ logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> Highlight? {
        let from = Dates.localDate(cal.date(byAdding: .day, value: -55, to: now) ?? now, cal)
        var best: Highlight?
        for (lift, pts) in liftHistory(logs.filter { $0.date >= from }).sorted(by: { $0.key < $1.key }) where pts.count >= 2 {
            let gain = pts[pts.count - 1].e1rm - pts[0].e1rm
            if gain >= 1 && (best == nil || gain > best!.gainKg) { best = Highlight(lift: lift, gainKg: gain, since: pts[0].date) }
        }
        return best
    }

    // MARK: Baseline and projection

    /// Cuts a line into stretches wholly above or below `baseline`, adding the crossing point to both neighbours so colours meet. A value on the baseline counts as above.
    public static func splitByBaseline(_ pts: [BaselineSegment.Point], baseline: Double) -> [BaselineSegment] {
        var out: [BaselineSegment] = []
        for (i, p) in pts.enumerated() {
            let above = p.v >= baseline
            if i > 0 {
                let q = pts[i - 1]
                if (q.v >= baseline) != above {
                    let f = (baseline - q.v) / (p.v - q.v)
                    let cross = BaselineSegment.Point(t: q.t + f * (p.t - q.t), v: baseline)
                    out[out.count - 1].pts.append(cross)
                    out.append(BaselineSegment(above: above, pts: [cross]))
                }
            }
            if out.isEmpty || out[out.count - 1].above != above { out.append(BaselineSegment(above: above, pts: [])) }
            out[out.count - 1].pts.append(p)
        }
        return out
    }

    /// For losing or keeping weight, above the baseline is bad; for building muscle it is the other way round.
    public static func baselineTone(above: Bool, goal: Goal?) -> Tone { above == (goal == .gain) ? .good : .bad }

    /// Where the current pace leads: the date it reaches the baseline, or why it does not.
    public static func projectToBaseline(currentKg: Double, perWeekKg: Double, baselineKg: Double, _ now: Date, _ cal: Calendar = .current) -> Projection {
        let gap = baselineKg - currentKg
        if abs(gap) < 0.3 { return Projection(state: .reached) }
        if abs(perWeekKg) < 0.02 { return Projection(state: .flat) }
        if (gap > 0) != (perWeekKg > 0) { return Projection(state: .away) }
        let weeks = gap / perWeekKg
        if weeks > 104 { return Projection(state: .far, weeks: weeks) }
        return Projection(state: .on, arrival: cal.date(byAdding: .day, value: Int((weeks * 7).rounded()), to: now), weeks: weeks)
    }

    /// The pace (kg per week, signed) needed to reach `targetKg` by `targetDate`; nil if that day is not in the future.
    public static func requiredPace(currentKg: Double, targetKg: Double, targetDate: String, _ now: Date, _ cal: Calendar = .current) -> (perWeekKg: Double, days: Int)? {
        guard let target = Dates.parse(targetDate, cal) else { return nil }
        let days = Dates.daysBetween(now, target, cal)
        guard days >= 1 else { return nil }
        return ((targetKg - currentKg) / (Double(days) / 7), days)
    }

    /// The weight the graph is measured against: your own target if set, else a healthy weight for your height (BMI 22.5).
    public static func baselineWeight(heightCm: Double?, targetWeightKg: Double?) -> (kg: Double, source: String)? {
        if let t = targetWeightKg, t > 0 { return (t, "target") }
        if let h = heightCm, h >= 100, h <= 250 { return (((22.5 * pow(h / 100, 2)) * 10).rounded() / 10, "bmi") }
        return nil
    }
}
