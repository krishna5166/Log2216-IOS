import Foundation

public struct Raise: Equatable, Sendable { public var name: String; public var from: Double; public var to: Double }   // working weights in the gym unit
public struct Stall: Equatable, Sendable { public var name: String; public var sessions: Int; public var deloadTo: Double }
public struct Progression: Equatable, Sendable { public var raise: [Raise]; public var stalled: [Stall]; public var deload: Bool }

/// Suggestions for next week, from what was logged. Information only: the plan holds no weights, so nothing is changed.
/// - raise: the last session hit the top of the rep range on every set (within three weeks): add one step;
/// - stalled: four or more sessions where the last three set no new best estimated max over at least two weeks;
/// - deload: two or more lifts stalled at once (usually tiredness, not one bad lift): about 90% of the working weight.
public enum Suggestions {
    public static func progression(plan: [TemplateDay], logs: [WorkoutLog], unit: WeightUnit, _ now: Date, _ cal: Calendar = .current) -> Progression {
        let today = Dates.localDate(now, cal)
        let tomorrow = Dates.addDays(today, 1, cal)
        let threeWeeksAgo = Dates.addDays(today, -21, cal)
        let step = Logging.step(unit)

        var names: [String] = []
        var raise: [Raise] = []
        for day in plan where day.type != .rest {
            for e in day.exercises where !names.contains(e.name) {
                names.append(e.name)
                guard let last = Plan.recentSessions(logs, name: e.name, before: tomorrow, unit: unit, count: 1).first,
                      last.date >= threeWeeksAgo, last.date <= today, Plan.readyToIncrease(e, last.sets) else { continue }
                let top = last.sets.map { Double($0.weight) ?? 0 }.max() ?? 0
                if top > 0 { raise.append(Raise(name: e.name, from: top, to: (top + step) * 100 / 100)) }
            }
        }

        let lifts = Insights.liftHistory(logs)
        var stalled: [Stall] = []
        for name in names {
            guard let pts = lifts[name], pts.count >= 4 else { continue }
            let lastThree = Array(pts.suffix(3)), earlier = Array(pts.dropLast(3))
            guard let a = Dates.parse(lastThree[0].date, cal), let b = Dates.parse(lastThree[2].date, cal), Dates.daysBetween(a, b, cal) >= 14 else { continue }
            if (lastThree.map(\.e1rm).max() ?? 0) > (earlier.map(\.e1rm).max() ?? 0) { continue }
            let working = Units.fromKg(lastThree.map(\.weight).max() ?? 0, to: unit)
            let rounded = Double(Nutrition.round(working * 0.9 / step)) * step
            stalled.append(Stall(name: name, sessions: pts.count, deloadTo: max(step, rounded)))
        }
        return Progression(raise: raise, stalled: stalled, deload: stalled.count >= 2)
    }
}
