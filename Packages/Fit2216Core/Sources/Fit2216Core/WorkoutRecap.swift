import Foundation

/// What a finished workout adds up to, for the "Workout complete" screen.
public struct WorkoutResult: Equatable, Sendable {
    public var exercises: Int      // exercises with at least one logged set
    public var sets: Int
    public var volumeKg: Double    // weight x reps over every logged set
    public var records: [String]   // lifts that set a personal best today
}

public enum WorkoutRecap {
    /// `lifts` must come from workouts before this one (as `Insights.liftHistory` of the earlier logs), so a first session is not a record.
    public static func result(log: WorkoutLog, lifts: [String: [LiftPoint]]) -> WorkoutResult {
        let unit = Units.logUnit(log)
        var sets = 0, exercises = 0, volume = 0.0
        for rows in log.sets.values {
            let done = rows.filter { Plan.filled($0) }
            if !done.isEmpty { exercises += 1 }
            sets += done.count
            for s in done { volume += Units.toKg(Insights.num(s.weight), from: unit) * Insights.num(s.reps) }
        }
        let records = PersonalBests.todaysRecords(log: log, lifts: lifts).map(\.name)
        return WorkoutResult(exercises: exercises, sets: sets, volumeKg: volume, records: records)
    }
}
