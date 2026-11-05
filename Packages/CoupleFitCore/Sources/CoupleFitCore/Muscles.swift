import Foundation

public enum Muscle: String, Codable, CaseIterable, Sendable {
    case chest, shoulders, biceps, triceps, forearms, abs, obliques, traps, lats, lowerback, glutes, adductors, quads, hamstrings, calves

    public var label: String {
        switch self {
        case .chest: return "Chest"; case .shoulders: return "Shoulders"; case .biceps: return "Biceps"; case .triceps: return "Triceps"
        case .forearms: return "Forearms"; case .abs: return "Abs"; case .obliques: return "Obliques"; case .traps: return "Traps"
        case .lats: return "Back"; case .lowerback: return "Lower back"; case .glutes: return "Glutes"; case .adductors: return "Inner thighs"
        case .quads: return "Quads"; case .hamstrings: return "Hamstrings"; case .calves: return "Calves"
        }
    }
}

public enum Load: Sendable { case primary, secondary }
public enum BodySide: Sendable { case front, back }

/// Which muscles an exercise name works. Generated from the web app's rules (app/src/lib/muscles.ts); keep the two in step.
public enum Muscles {
    private struct Rule {
        let regex: NSRegularExpression
        let primary: [Muscle]
        let secondary: [Muscle]
        init(_ pattern: String, _ p: [Muscle], _ s: [Muscle]) {
            regex = try! NSRegularExpression(pattern: pattern, options: [])
            primary = p; secondary = s
        }
        func matches(_ text: String) -> Bool { regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil }
    }

    // First match wins, so order matters: "leg curl" must not match "curl", "leg press" not "press".
    private static let rules: [Rule] = [
        Rule(#"adduct"#, [.adductors], []),
        Rule(#"abduct|clam|hip circle"#, [.glutes], []),
        Rule(#"leg curl|hamstring|nordic"#, [.hamstrings], [.calves]),
        Rule(#"calf|calves"#, [.calves], []),
        Rule(#"leg extension"#, [.quads], []),
        Rule(#"leg press|hack|squat|lunge|step.?up|sissy"#, [.quads, .glutes], [.hamstrings]),
        Rule(#"deadlift|rdl|romanian|good.?morning|pull.?through|hip thrust|glute|bridge|kickback.*(cable|glute)"#, [.glutes, .hamstrings], [.lowerback]),
        Rule(#"back extension|hyperextension"#, [.lowerback], [.glutes, .hamstrings]),
        Rule(#"devil|burpee|thruster"#, [], [.shoulders, .quads, .glutes, .chest]),
        Rule(#"kettlebell swing|swing|clean|snatch"#, [.glutes, .hamstrings], [.shoulders, .lowerback]),
        Rule(#"face pull|rear delt|reverse fly|reverse pec"#, [.traps], [.shoulders]),
        Rule(#"shrug"#, [.traps], [.forearms]),
        Rule(#"lateral raise|front raise|upright row"#, [.shoulders], [.traps]),
        Rule(#"dip|close.?grip|skull|tricep|pushdown|push.?down|extension|kickback"#, [.triceps], [.chest, .shoulders]),
        Rule(#"shoulder|overhead|ohp|military|arnold|landmine press"#, [.shoulders], [.triceps, .traps]),
        Rule(#"pull.?up|chin.?up|pulldown|pull.?down|\blats?\b|pullover|row"#, [.lats], [.biceps, .traps, .forearms]),
        Rule(#"torso rotat|rotary torso"#, [.obliques], [.abs]),
        Rule(#"bench|chest|pec|fly|flye|push.?up|crossover"#, [.chest], [.shoulders, .triceps]),
        Rule(#"curl|bicep|hammer|preacher"#, [.biceps], [.forearms]),
        Rule(#"twist|pallof|woodchop|side bend|oblique|suitcase"#, [.obliques, .abs], []),
        Rule(#"crunch|sit.?up|plank|leg raise|knee raise|\babs?\b|ab wheel|rollout|hollow|dead bug"#, [.abs], [.obliques]),
        Rule(#"carry|farmer|grip|wrist|forearm"#, [.forearms], [.traps]),
        Rule(#"press"#, [.chest], [.shoulders, .triceps]),
    ]

    private static let byDayName: [(Rule, [Muscle])] = [
        (Rule("push", [], []), [.chest, .shoulders, .triceps]),
        (Rule("pull", [], []), [.lats, .biceps, .traps]),
        (Rule("leg|lower", [], []), [.quads, .hamstrings, .glutes, .calves]),
        (Rule("upper", [], []), [.chest, .lats, .shoulders, .biceps, .triceps]),
        (Rule("abs|core", [], []), [.abs, .obliques]),
        (Rule("arm", [], []), [.biceps, .triceps, .forearms]),
    ]

    /// The muscles an exercise works, guessed from its name. Unknown names return nothing rather than guessing wrong.
    public static func forName(_ name: String) -> (primary: [Muscle], secondary: [Muscle]) {
        let n = name.lowercased()
        guard let hit = rules.first(where: { $0.matches(n) }) else { return ([], []) }
        return (hit.primary, hit.secondary)
    }

    /// The muscles you chose for an exercise, else the guess from its name.
    public static func forExercise(_ e: TemplateExercise) -> (primary: [Muscle], secondary: [Muscle]) {
        if let chosen = e.muscles, !chosen.isEmpty { return (chosen, []) }
        return forName(e.name)
    }

    /// Muscles a planned day works: hardest-worked by any exercise is primary, otherwise secondary. Falls back to the day name.
    public static func forDay(_ day: TemplateDay) -> [Muscle: Load] {
        var out: [Muscle: Load] = [:]
        for e in day.exercises {
            let (p, s) = forExercise(e)
            for m in s where out[m] == nil { out[m] = .secondary }
            for m in p { out[m] = .primary }
        }
        if out.isEmpty {
            let n = day.name.lowercased()
            for (rule, ms) in byDayName where rule.matches(n) { for m in ms { out[m] = .primary } }
        }
        return out
    }

    private static let frontWeight: [Muscle: Double] = [.chest: 2, .quads: 4, .adductors: 1, .biceps: 1.5, .shoulders: 1, .abs: 0.5, .obliques: 0.25]
    private static let backWeight: [Muscle: Double] = [.lats: 2, .traps: 1, .triceps: 1, .lowerback: 0.75, .glutes: 1.5, .hamstrings: 1.5]

    /// Which side of the body to show: the one holding more of what the day mainly works (front on a tie). Helpers do not turn it.
    public static func side(for muscles: [Muscle: Load]) -> BodySide {
        var front = 0.0, back = 0.0
        for (m, load) in muscles where load == .primary { front += frontWeight[m] ?? 0; back += backWeight[m] ?? 0 }
        return back > front ? .back : .front
    }
}
