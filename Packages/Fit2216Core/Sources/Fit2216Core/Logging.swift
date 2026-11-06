import Foundation

/// Editing one workout while it is being done. Pure functions: the screen holds the log and calls these. A port of the
/// logging parts of the web app's exercise screen, including the fix for the "skipped set leaves a hole" bug.
public enum Logging {
    /// Weight step: 5 lb or 2.5 kg.
    public static func step(_ unit: WeightUnit) -> Double { unit == .lb ? 5 : 2.5 }

    /// The Firestore document id the web app uses: `date_dayIndex`, or just the date on very old logs.
    public static func documentID(_ log: WorkoutLog) -> String { log.dayIndex.map { "\(log.date)_\($0)" } ?? log.date }

    /// The log for `day` on `date`: the saved one if there is one, else a new empty one.
    /// A log with nothing typed yet takes your gym unit; one with sets keeps the unit it was typed in (no silent conversion).
    public static func open(day: TemplateDay, date: String, existing: [WorkoutLog], gymUnit: WeightUnit) -> WorkoutLog {
        if var log = existing.first(where: { $0.date == date && $0.dayIndex == day.day }) {
            if !Units.hasSets(log) { log.unit = gymUnit }
            return log
        }
        return WorkoutLog(date: date, dayName: day.name, dayIndex: day.day, unit: gymUnit, sets: [:])
    }

    /// The day to follow while logging: a one-off copied template if the log has one, else the plan's day.
    public static func day(for log: WorkoutLog, plan: [TemplateDay], fallback: TemplateDay) -> TemplateDay {
        log.template ?? plan.first { $0.day == log.dayIndex } ?? fallback
    }

    /// Sets `weight` and/or `reps` of one set. Earlier sets are padded with empty ones, so logging set 3 first never leaves a hole.
    public static func setting(_ log: WorkoutLog, exercise: String, index: Int, weight: String? = nil, reps: String? = nil) -> WorkoutLog {
        var out = log
        var rows = out.sets[exercise] ?? []
        while rows.count <= index { rows.append(SetLog()) }
        if let weight { rows[index].weight = weight }
        if let reps { rows[index].reps = reps }
        out.sets[exercise] = rows
        return out
    }

    /// The rows to show for an exercise: one per planned set, empty where nothing is logged yet.
    public static func rows(_ log: WorkoutLog, exercise: TemplateExercise) -> [SetLog] {
        (0..<max(exercise.sets, 0)).map { log.sets[exercise.name]?[safe: $0] ?? SetLog() }
    }

    public static func setsLogged(_ log: WorkoutLog, exercise: String) -> Int { (log.sets[exercise] ?? []).filter { Plan.filled($0) }.count }

    /// The first exercise that still has sets to do (or the first one if all are done), to open on.
    public static func firstOpenIndex(day: TemplateDay, log: WorkoutLog) -> Int {
        day.exercises.firstIndex { setsLogged(log, exercise: $0.name) < $0.sets } ?? 0
    }

    public static func finished(_ log: WorkoutLog) -> WorkoutLog { var l = log; l.done = true; l.skipped = false; return l }
    public static func skipped(_ log: WorkoutLog) -> WorkoutLog { var l = log; l.skipped = true; l.done = false; return l }

    /// Last time this lift was done before `date`, weights shown in `unit`.
    public static func lastTime(name: String, history: [WorkoutLog], before date: String, unit: WeightUnit) -> (date: String, sets: [SetLog])? {
        Plan.recentSessions(history, name: name, before: date, unit: unit, count: 1).first
    }

    /// What the next set most likely is: the set just done, else the same set last time (weight up one step once every set hit the top of the range).
    public static func suggestion(exercise: TemplateExercise, shownName: String, index: Int, log: WorkoutLog, history: [WorkoutLog], unit: WeightUnit) -> SetLog? {
        let last = lastTime(name: shownName, history: history, before: log.date, unit: unit)?.sets
        let ready = Plan.readyToIncrease(exercise, last)
        return Plan.suggestSet(current: log.sets[exercise.name], index: index, last: last, ready: ready, step: step(unit))
    }

    /// True when this edit just logged a set (reps went from empty to filled) and a rest should start. No rest after the very last set of the workout.
    public static func shouldStartRest(before: WorkoutLog, after: WorkoutLog, exercise: TemplateExercise, index: Int, day: TemplateDay) -> Bool {
        let was = Plan.filled(before.sets[exercise.name]?[safe: index])
        let now = Plan.filled(after.sets[exercise.name]?[safe: index])
        guard !was, now else { return false }
        let isLastExercise = day.exercises.last?.name == exercise.name
        return !(isLastExercise && index >= exercise.sets - 1)
    }
}
