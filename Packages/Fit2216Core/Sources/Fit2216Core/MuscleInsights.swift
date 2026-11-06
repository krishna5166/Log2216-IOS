import Foundation

public struct MuscleStat: Equatable, Sendable {
    public enum Range: Sendable { case none, low, good, high }
    public var muscle: Muscle
    public var setsThisWeek: Double        // main muscle counts 1 per set, helpers 0.5
    public var weeklyAverage: Double       // average per week over the last 4 weeks (this week included)
    public var lastTrained: String?
    public var daysSince: Int?
    public var topLift: String?            // the lift with the highest estimated max among those that mainly work this muscle
    public var strengthChangeKg: Double?   // change in that lift's estimated max over the last 8 weeks (needs 2+ sessions)
    public var strengthChangePercent: Double?
    public var range: Range                // where the 4-week weekly average sits against a typical 8 to 20 sets
}

public struct BalanceFlag: Equatable, Sendable {
    public var title: String
    public var detail: String
}

/// Strength and volume by body part. Which muscle an exercise works comes from `Muscles` (your chosen muscles first, else the name).
public enum MuscleInsights {
    public static let lowSets = 8.0, highSets = 20.0

    private struct Row { var muscle: Muscle; var weight: Double; var date: String; var lift: String; var primary: Bool }

    /// Every logged set as (muscle, weight, date, lift). Uses the plan day's own exercise settings when the lift is in the plan.
    private static func rows(plan: [TemplateDay], logs: [WorkoutLog]) -> [Row] {
        var out: [Row] = []
        for log in logs where log.skipped != true {
            let day = log.template ?? plan.first { Plan.matches(log, $0) }
            for (orig, sets) in log.sets {
                let done = sets.filter { Plan.filled($0) }.count
                guard done > 0 else { continue }
                let shown = Plan.effectiveName(log, orig)
                let exercise = day?.exercises.first { $0.name == orig && shown == orig } ?? TemplateExercise(name: shown, sets: done, reps: "")
                let (primary, secondary) = Muscles.forExercise(exercise)
                for m in primary { out.append(Row(muscle: m, weight: Double(done), date: log.date, lift: shown, primary: true)) }
                for m in secondary where !primary.contains(m) { out.append(Row(muscle: m, weight: Double(done) * 0.5, date: log.date, lift: shown, primary: false)) }
            }
        }
        return out
    }

    public static func stats(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> [MuscleStat] {
        let rows = rows(plan: plan, logs: logs)
        let weekStart = Dates.weekStart(now, cal)
        let fourWeeksAgo = Dates.addDays(weekStart, -21, cal)
        let lifts = Insights.liftHistory(logs)
        let eightWeeksAgo = Dates.addDays(Dates.localDate(now, cal), -55, cal)

        // the lifts that mainly work each muscle, for picking its top lift (a helper-only lift would credit the wrong muscle)
        var mainLifts: [Muscle: Set<String>] = [:]
        for r in rows where r.primary { mainLifts[r.muscle, default: []].insert(r.lift) }

        return Muscle.allCases.compactMap { muscle -> MuscleStat? in
            let mine = rows.filter { $0.muscle == muscle }
            guard !mine.isEmpty else { return nil }
            let thisWeek = mine.filter { $0.date >= weekStart }.reduce(0) { $0 + $1.weight }
            let recent = mine.filter { $0.date >= fourWeeksAgo }.reduce(0) { $0 + $1.weight }
            let average = recent / 4
            let last = mine.map(\.date).max()
            let days = last.flatMap { Dates.parse($0, cal) }.map { Dates.daysBetween($0, now, cal) }

            var top: String?, topE1rm = 0.0
            for name in mainLifts[muscle] ?? [] {
                guard let best = lifts[name]?.map(\.e1rm).max(), best > topE1rm else { continue }
                top = name; topE1rm = best
            }
            var change: Double?, pct: Double?
            if let top, let pts = lifts[top]?.filter({ $0.date >= eightWeeksAgo }), pts.count >= 2, let first = pts.first, let latest = pts.last, first.e1rm > 0 {
                change = latest.e1rm - first.e1rm
                pct = (latest.e1rm - first.e1rm) / first.e1rm * 100
            }
            let range: MuscleStat.Range = average <= 0 ? .none : average < lowSets ? .low : average > highSets ? .high : .good
            return MuscleStat(muscle: muscle, setsThisWeek: thisWeek, weeklyAverage: average, lastTrained: last, daysSince: days,
                              topLift: top, strengthChangeKg: change, strengthChangePercent: pct, range: range)
        }.sorted { $0.weeklyAverage > $1.weeklyAverage }
    }

    /// Plain-language balance warnings from the 4-week averages: push vs pull, quads vs hamstrings, and muscles in the plan that have gone untrained.
    public static func balance(stats: [MuscleStat], plan: [TemplateDay]) -> [BalanceFlag] {
        func avg(_ ms: [Muscle]) -> Double { stats.filter { ms.contains($0.muscle) }.reduce(0) { $0 + $1.weeklyAverage } }
        var flags: [BalanceFlag] = []
        let push = avg([.chest, .shoulders, .triceps]), pull = avg([.lats, .traps, .biceps])
        if push > 0 && pull > 0 {
            if push / pull > 1.5 { flags.append(BalanceFlag(title: "Pushing more than pulling", detail: "About \(Int(push.rounded())) push sets a week against \(Int(pull.rounded())) pull sets.")) }
            else if pull / push > 1.5 { flags.append(BalanceFlag(title: "Pulling more than pushing", detail: "About \(Int(pull.rounded())) pull sets a week against \(Int(push.rounded())) push sets.")) }
        }
        let quads = avg([.quads]), hams = avg([.hamstrings])
        if quads > 0 && hams > 0 && quads / hams > 2 { flags.append(BalanceFlag(title: "Quads well ahead of hamstrings", detail: "About \(Int(quads.rounded())) quad sets a week against \(Int(hams.rounded())) hamstring sets.")) }
        let planned = Set(plan.flatMap { $0.exercises.flatMap { Muscles.forExercise($0).primary } })
        for stat in stats where planned.contains(stat.muscle) && (stat.daysSince ?? 0) >= 10 {
            flags.append(BalanceFlag(title: "\(stat.muscle.label) not trained in \(stat.daysSince ?? 0) days", detail: "It is in your plan but has no recent sets."))
        }
        return flags
    }
}
