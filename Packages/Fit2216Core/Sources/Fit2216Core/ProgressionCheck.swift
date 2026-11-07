import Foundation

/// Whether each lift of the workout `Plan.pick` chooses is eligible for more load, with the reason and the evidence.
/// Information only: it never changes a plan or a logged workout, and it never prescribes an increment (the plan has no
/// weight settings). Anything incomplete, swapped, skipped, uneven or unreadable is a hold or no data, never an increase.
public enum ProgressionCheck {
    public enum Status: String, Equatable, Sendable { case eligibleToIncrease, hold, noData }

    public enum Reason: String, Equatable, Sendable {
        case allSetsReachedTarget       // every prescribed set, same load, reached the top of the rep range
        case repsBelowTarget            // at least one prescribed set fell short of the top of the range
        case incompleteSets             // fewer sets logged than prescribed
        case unevenLoads                // the prescribed sets used different loads, so there is no single load to raise
        case noLoad                     // no weight entered, or 0 (bodyweight): nothing to raise
        case invalidEntry               // a weight or reps value that is not a readable number
        case skippedLastTime            // the latest session with this lift was marked skipped
        case swappedLastTime            // last time this lift was swapped for another exercise
        case staleHistory               // the latest session is older than `staleAfterDays`
        case noHistory                  // never logged before the given date
        case noRepTarget                // the plan's reps have no number (e.g. "AMRAP")
    }

    public struct Evidence: Equatable, Sendable {
        public var date: String?        // the session judged
        public var load: Double?        // its load, in the requested unit
        public var reps: [Int]          // reps of the prescribed sets judged, in order
        public var prescribedSets: Int
        public var targetReps: Int      // top of the plan's rep range
        public var unit: WeightUnit
    }

    public struct Advice: Equatable, Sendable {
        public var exercise: String
        public var status: Status
        public var reason: Reason
        public var evidence: Evidence
    }

    public struct NextWorkout: Equatable, Sendable {
        public var picked: PickedWorkout
        public var advice: [Advice]     // one per exercise, plan order; empty on a rest day
    }

    /// Same window `Suggestions.progression` already uses for a raise (three weeks).
    public static let staleAfterDays = 21

    /// Advice for the workout `Plan.pick` would open now. Today's own log is excluded, so a half-done session today never
    /// counts as evidence. Optional exercises are included and judged the same way.
    public static func nextWorkout(plan: [TemplateDay], logs: [WorkoutLog], unit: WeightUnit, _ now: Date, _ cal: Calendar = .current) -> NextWorkout? {
        guard let picked = Plan.pick(plan, logs, now, cal) else { return nil }
        let today = Dates.localDate(now, cal)
        let advice = picked.day.type == .rest ? [] : picked.day.exercises.map { evaluate($0, logs: logs, before: today, unit: unit, cal) }
        return NextWorkout(picked: picked, advice: advice)
    }

    /// Judges one exercise against its latest earlier session (logs dated before `date`).
    public static func evaluate(_ ex: TemplateExercise, logs: [WorkoutLog], before date: String, unit: WeightUnit, _ cal: Calendar = .current) -> Advice {
        let name = ExerciseNames.canonical(ex.name)
        let target = Plan.topReps(ex.reps)
        var ev = Evidence(date: nil, load: nil, reps: [], prescribedSets: ex.sets, targetReps: target, unit: unit)
        func out(_ s: Status, _ r: Reason) -> Advice { Advice(exercise: ex.name, status: s, reason: r, evidence: ev) }
        guard target > 0 else { return out(.noData, .noRepTarget) }

        for log in logs.filter({ $0.date < date }).sorted(by: { $0.date > $1.date }) {
            // The latest session that planned or performed this lift decides; older history is not used to get around it.
            let performed = log.sets.sorted(by: { $0.key < $1.key }).first { Plan.effectiveName(log, $0.key) == name }
            let swappedAway = log.swaps?.contains { ExerciseNames.canonical($0.key) == name && !$0.value.isEmpty && ExerciseNames.canonical($0.value) != name } ?? false
            guard performed != nil || swappedAway else { continue }
            ev.date = log.date
            if log.skipped == true { return out(.hold, .skippedLastTime) }
            if swappedAway, performed.map({ !$0.value.contains(where: Plan.filled) }) ?? true { return out(.hold, .swappedLastTime) }
            guard let rows = performed?.value else { continue }
            if let d = Dates.parse(log.date, cal), let ref = Dates.parse(date, cal), Dates.daysBetween(d, ref, cal) > staleAfterDays {
                return out(.hold, .staleHistory)
            }
            let working = Array(rows.filter(Plan.filled).prefix(ex.sets))
            var loads: [Double] = [], reps: [Int] = []
            for s in working {
                let r = s.reps.trimmingCharacters(in: .whitespaces)
                let w = s.weight.trimmingCharacters(in: .whitespaces)
                guard let n = Int(r), n >= 0 else { return out(.hold, .invalidEntry) }
                reps.append(n)
                if w.isEmpty { loads.append(0); continue }
                guard let v = Double(w), v.isFinite, v >= 0 else { return out(.hold, .invalidEntry) }
                loads.append(Units.convert(v, from: Units.logUnit(log), to: unit))
            }
            ev.reps = reps
            guard working.count >= ex.sets else { return out(.hold, .incompleteSets) }
            guard let first = loads.first, loads.allSatisfy({ abs($0 - first) < 0.01 }) else { return out(.hold, .unevenLoads) }
            guard first > 0 else { return out(.hold, .noLoad) }
            ev.load = (first * 10).rounded() / 10
            return reps.allSatisfy({ $0 >= target }) ? out(.eligibleToIncrease, .allSetsReachedTarget) : out(.hold, .repsBelowTarget)
        }
        return out(.noData, .noHistory)
    }
}
