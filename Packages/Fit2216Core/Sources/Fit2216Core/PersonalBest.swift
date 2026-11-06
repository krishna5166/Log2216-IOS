import Foundation

public struct PersonalBest: Equatable, Sendable {
    public var weight: Double   // in the unit asked for
    public var reps: Double
    public var gain: Double     // estimated-max gain over the old best, in the unit asked for
}

/// A set today that beats every earlier session of a lift. A port of app/src/lib/pr.ts.
public enum PersonalBests {
    /// Whether today's sets of one lift beat everything before today (by estimated max). `history` is that lift's earlier sessions (kg);
    /// a first-ever session is not a record, only a start. Sets are in `unit`. Returns the set that did it.
    public static func best(history: [LiftPoint]?, sets: [SetLog], unit: WeightUnit) -> PersonalBest? {
        guard let history, !history.isEmpty, let before = history.map(\.e1rm).max() else { return nil }
        var best: (w: Double, r: Double, est: Double)?
        for s in sets {
            let w = Units.toKg(Double(s.weight) ?? 0, from: unit), r = Double(s.reps) ?? 0, est = Insights.e1rm(weight: w, reps: r)
            if est > 0 && (best == nil || est > best!.est) { best = (w, r, est) }
        }
        guard let best, best.est > before * (1 + 1e-9) else { return nil }
        return PersonalBest(weight: Units.fromKg(best.w, to: unit), reps: best.r, gain: Units.fromKg(best.est - before, to: unit))
    }

    /// Every lift in a workout that set a record today, by the name actually done. `lifts` must come from workouts before today.
    public static func todaysRecords(log: WorkoutLog, lifts: [String: [LiftPoint]]) -> [(name: String, best: PersonalBest)] {
        let unit = Units.logUnit(log)
        return log.sets.sorted { $0.key < $1.key }.compactMap { orig, sets in
            let name = Plan.effectiveName(log, orig)
            return best(history: lifts[name], sets: sets, unit: unit).map { (name, $0) }
        }
    }
}
