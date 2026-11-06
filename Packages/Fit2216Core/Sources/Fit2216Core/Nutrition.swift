import Foundation

public struct Targets: Equatable, Sendable {
    public var kcal: Int
    public var protein: Int
    public var proteinMin: Int
    public var proteinMax: Int
    public var carbs: Int
    public var fat: Int
    public var bmr: Int
    public var tdee: Int
    public var sessions: Double
}

/// Daily calorie and macro targets from your body details and training. A port of app/src/lib/nutrition.ts.
public enum Nutrition {
    /// Rounds half up, like JavaScript's Math.round (for the positive numbers used here).
    static func round(_ x: Double) -> Int { Int((x + 0.5).rounded(.down)) }

    public static func hasBodyDetails(_ p: Profile) -> Bool {
        guard p.sex != nil, let age = p.age, let h = p.heightCm, let w = p.weightKg else { return false }
        return age > 0 && h > 0 && w > 0
    }

    /// Mifflin–St Jeor BMR + lifestyle + training sessions, adjusted for the goal. Nil until sex, age, height and weight are filled in.
    public static func computeTargets(_ p: Profile, autoSessions: Double) -> Targets? {
        guard hasBodyDetails(p), let w = p.weightKg, let h = p.heightCm, let a = p.age else { return nil }
        let sessions = min(7, max(0, p.sessionsMode == .manual ? (p.sessionsPerWeek ?? 0) : autoSessions))
        let goal = p.goal ?? .maintain
        let lifestyle: Double = { switch p.lifestyle ?? .sitting { case .sitting: return 1.2; case .standing: return 1.3; case .physical: return 1.4 } }()
        let goalFactor: Double = { switch goal { case .lose: return 0.8; case .maintain: return 1; case .gain: return 1.1 } }()

        let bmr = 10 * w + 6.25 * h - 5 * a + (p.sex == .male ? 5 : -161)
        let tdee = bmr * lifestyle + (sessions * 300) / 7
        let kcal = round((tdee * goalFactor) / 10) * 10

        let (lo, hi): (Double, Double) = goal == .lose ? (1.8, 2.2) : (1.6, 2.0)
        let protein = round(((lo + hi) / 2) * w)
        let fat = max(round((0.25 * Double(kcal)) / 9), round(0.7 * w))
        let carbs = max(0, round((Double(kcal) - Double(protein) * 4 - Double(fat) * 9) / 4))
        return Targets(kcal: kcal, protein: protein, proteinMin: round(lo * w), proteinMax: round(hi * w), carbs: carbs, fat: fat,
                       bmr: round(bmr), tdee: round(tdee), sessions: Double(round(sessions * 10)) / 10)
    }

    /// Training sessions per week from what was logged (not skipped) over up to the last 4 weeks; with no history, the plan's training days.
    public static func avgSessions(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, _ cal: Calendar = .current) -> Double {
        let planned = Double(plan.filter { $0.type != .rest && !$0.exercises.isEmpty }.count)
        let from = Dates.localDate(cal.date(byAdding: .day, value: -27, to: now) ?? now, cal)
        let counted = logs.filter { l in
            guard l.date >= from, l.skipped != true else { return false }
            let day = plan.first { l.dayIndex != nil ? $0.day == l.dayIndex : $0.name == l.dayName }
            return day.map { Plan.isComplete(l, $0) } ?? (l.done == true)
        }
        guard let first = counted.map(\.date).min(), let firstDate = Dates.parse(first, cal) else { return planned }
        let days = max(7, min(28, Dates.daysBetween(firstDate, now, cal) + 1))
        return min(7, Double(round((Double(counted.count) / (Double(days) / 7)) * 10)) / 10)
    }
}
