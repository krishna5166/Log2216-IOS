import Foundation

/// One name an exercise has been logged under, and how many workouts used it.
public struct DriftName: Equatable, Sendable { public var name: String; public var count: Int }

/// Several spellings of what is really one exercise ("Squat", "Squats", "Romanian squat" after a rename).
public struct DriftGroup: Equatable, Sendable {
    public var names: [DriftName]
    public var target: String   // the name to keep: the plan's own spelling if there is one, else the most used
}

/// Keeps one exercise under one name, so lift history, personal bests and trends stitch together after a rename.
public enum ExerciseNames {
    /// Old names that now mean another exercise (lowercase key to the current name). Add a line when you rename something in the plan.
    public static let aliases: [String: String] = [
        "romanian squat": "Squat",
    ]

    /// Trimmed, with runs of spaces collapsed.
    public static func tidy(_ name: String) -> String {
        name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The name history is grouped under: tidied, and mapped through the alias list.
    public static func canonical(_ name: String) -> String {
        let t = tidy(name)
        return aliases[t.lowercased()] ?? t
    }

    /// A loose key for spotting the same exercise written differently: lowercase, no punctuation, simple plurals folded.
    public static func key(_ name: String) -> String {
        let cleaned = canonical(name).lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }
        let words = String(cleaned).split(separator: " ").map { w -> String in
            var s = String(w)
            if s.count > 3, s.hasSuffix("s"), !s.hasSuffix("ss") { s.removeLast() }
            return s
        }
        return words.joined(separator: " ")
    }

    /// Spellings of one exercise found in the plan and the logs. Only names that were really logged (or are in the plan) count.
    public static func drift(plan: [TemplateDay], logs: [WorkoutLog]) -> [DriftGroup] {
        var counts: [String: Int] = [:]
        var planNames: [String] = []
        for d in plan { for e in d.exercises { counts[e.name, default: 0] += 0; planNames.append(e.name) } }
        for log in logs where log.skipped != true {
            for (orig, sets) in log.sets where sets.contains(where: { Plan.filled($0) }) {
                let used = (log.swaps?[orig]).flatMap { $0.isEmpty ? nil : $0 } ?? orig
                counts[used, default: 0] += 1
            }
        }
        var byKey: [String: [String]] = [:]
        for name in counts.keys.sorted() { byKey[key(name), default: []].append(name) }
        return byKey.compactMap { k, names -> DriftGroup? in
            guard names.count > 1 else { return nil }
            let ranked = names.map { DriftName(name: $0, count: counts[$0] ?? 0) }.sorted { ($0.count, $1.name) > ($1.count, $0.name) }
            let target = planNames.first { key($0) == k }.map(canonical) ?? canonical(ranked[0].name)
            return DriftGroup(names: ranked, target: target)
        }
        .sorted { $0.target < $1.target }
    }

    /// The logs that would change if every group were renamed to its target, plus how many were left alone
    /// (a log that already uses both spellings is not merged automatically).
    public static func rename(logs: [WorkoutLog], groups: [DriftGroup]) -> (changed: [WorkoutLog], skipped: Int) {
        var map: [String: String] = [:]
        for g in groups { for n in g.names where n.name != g.target { map[n.name] = g.target } }
        var changed: [WorkoutLog] = [], skipped = 0
        for log in logs {
            var out = log
            var touched = false, blocked = false
            for (orig, sets) in log.sets {
                if let swapped = log.swaps?[orig], !swapped.isEmpty {
                    if let to = map[swapped] { out.swaps?[orig] = to; touched = true }
                } else if let to = map[orig] {
                    if out.sets[to] != nil { blocked = true; continue }
                    out.sets[to] = sets
                    out.sets[orig] = nil
                    if let s = out.swaps?[orig] { out.swaps?[to] = s; out.swaps?[orig] = nil }
                    touched = true
                }
            }
            if blocked { skipped += 1 } else if touched { changed.append(out) }
        }
        return (changed, skipped)
    }
}
