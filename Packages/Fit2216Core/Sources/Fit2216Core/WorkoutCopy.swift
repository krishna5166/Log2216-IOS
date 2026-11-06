import Foundation

public enum WorkoutCopy {
    /// A one-off copy of someone's workout for `date`: their targets and today's swaps, never performed sets or completion.
    /// The weekly plan is not touched; the copy lives on the log as its `template`.
    public static func copy(source: TemplateDay, logged: WorkoutLog?, date: String, dayIndex: Int) -> WorkoutLog {
        var template = source
        template.day = dayIndex
        var swaps: [String: String] = [:]
        for e in source.exercises {
            let shown = logged.map { Plan.effectiveName($0, e.name) } ?? e.name
            if shown != e.name { swaps[e.name] = shown }
        }
        return WorkoutLog(date: date, dayName: source.name, dayIndex: dayIndex, done: false, skipped: false, sets: [:], template: template, swaps: swaps)
    }
}
