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

    /// The day a logged workout followed: its own copy, else the plan day, else rebuilt from what was logged.
    public static func sourceDay(for log: WorkoutLog, plan: [TemplateDay]) -> TemplateDay? {
        if let t = log.template, !t.exercises.isEmpty { return t }
        if let d = plan.first(where: { Plan.matches(log, $0) }), !d.exercises.isEmpty { return d }
        let rebuilt = log.sets.keys.sorted().compactMap { orig -> TemplateExercise? in
            let done = (log.sets[orig] ?? []).filter { Plan.filled($0) }.count
            return done > 0 ? TemplateExercise(name: orig, sets: done, reps: "8") : nil
        }
        guard !rebuilt.isEmpty else { return nil }
        return TemplateDay(day: log.dayIndex ?? 0, name: log.dayName, type: .strength, exercises: rebuilt)
    }

    // MARK: Share and import (no accounts needed: a workout travels as text through any share sheet)

    private struct Envelope: Codable { var app: String; var kind: String; var v: Int; var day: TemplateDay }

    /// The workout as shareable text, with the exercise names it was done under (swaps applied).
    public static func export(log: WorkoutLog, plan: [TemplateDay]) -> String? {
        guard var day = sourceDay(for: log, plan: plan) else { return nil }
        day.exercises = day.exercises.map { var e = $0; e.name = Plan.effectiveName(log, e.name); return e }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(Envelope(app: "fit2216", kind: "workout", v: 1, day: day)) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// A shared workout, or nil when the text is not one of ours or looks unsound.
    public static func parse(_ text: String) -> TemplateDay? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}"), start < end,
              let env = try? JSONDecoder().decode(Envelope.self, from: Data(trimmed[start...end].utf8)),
              env.app == "fit2216", env.kind == "workout", env.v == 1 else { return nil }
        var day = env.day
        day.exercises = day.exercises.prefix(40).map { var e = $0; e.name = ExerciseNames.tidy(e.name); e.sets = min(max(e.sets, 1), 20); return e }
        day.exercises.removeAll { $0.name.isEmpty || $0.name.count > 100 }
        day.name = ExerciseNames.tidy(day.name).prefix(60).description
        return day.exercises.isEmpty ? nil : day
    }
}
