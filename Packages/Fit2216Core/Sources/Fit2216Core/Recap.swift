import Foundation

public struct RecapRecord: Equatable, Sendable { public var name: String; public var weightKg: Double; public var reps: Double }

public struct WeekRecap: Equatable, Sendable {
    public var label: String          // "Last week", "This week so far" or "This week"
    public var from: String
    public var to: String
    public var done: Int
    public var planned: Int
    public var records: [RecapRecord] // lifts whose estimated max beat everything before that week
    public var latestKg: Double?      // newest weigh-in up to the end of the week
    public var changeKg: Double?      // against the newest weigh-in before the week began
    public var macroAvg: Int?         // average completion % over the days that have one
    public var macroDays: Int
}

public struct DayCell: Equatable, Sendable {
    public enum Trained: Sendable { case none, done, part, skipped }
    public var date: String
    public var trained: Trained
    public var macroPct: Int?
    public var today: Bool
    public var future: Bool
}

/// A week in review and the last few weeks as a calendar. A port of app/src/lib/recap.ts.
public enum Recap {
    /// Monday of the week to recap: on a Monday the week just ended (this one is empty), any other day the current week.
    public static func anchor(_ now: Date, _ cal: Calendar = .current) -> (start: Date, label: String) {
        let monday = Dates.monday(of: now, cal)
        let weekday = Dates.weekday(now, cal)
        if weekday == 1 { return (cal.date(byAdding: .day, value: -7, to: monday) ?? monday, "Last week") }
        return (monday, weekday == 0 ? "This week" : "This week so far")
    }

    public static func week(plan: [TemplateDay], logs: [WorkoutLog], weights: [WeightEntry], percents: [String: Int], _ now: Date, _ cal: Calendar = .current) -> WeekRecap {
        let (start, label) = anchor(now, cal)
        let days = Dates.weekDates(start, cal)
        let from = Dates.localDate(days[0], cal), to = Dates.localDate(days[6], cal)
        let inWeek = logs.filter { $0.date >= from && $0.date <= to }
        let training = Plan.sort(plan).filter { $0.type != .rest && !$0.exercises.isEmpty }
        let done = training.filter { d in inWeek.contains { $0.skipped != true && Plan.matches($0, d) && Plan.isComplete($0, d) } }.count

        var records: [RecapRecord] = []
        for (name, pts) in Insights.liftHistory(logs.filter { $0.date <= to }).sorted(by: { $0.key < $1.key }) {
            let before = pts.filter { $0.date < from }, during = pts.filter { $0.date >= from }
            guard !before.isEmpty, let top = during.max(by: { $0.e1rm < $1.e1rm }) else { continue }
            let prior = before.map(\.e1rm).max() ?? 0
            if top.e1rm > prior * (1 + 1e-9) { records.append(RecapRecord(name: name, weightKg: top.weight, reps: top.reps)) }
        }

        let sorted = weights.sorted { $0.date > $1.date }
        let latest = sorted.first { $0.date <= to }
        let prev = sorted.first { $0.date < from }
        let marks = days.compactMap { percents[Dates.localDate($0, cal)] }
        var change: Double?
        if let latest, let prev, latest.date >= from { change = latest.kg - prev.kg }
        return WeekRecap(label: label, from: from, to: to, done: done, planned: training.count, records: records, latestKg: latest?.kg, changeKg: change,
                         macroAvg: marks.isEmpty ? nil : Nutrition.round(Double(marks.reduce(0, +)) / Double(marks.count)), macroDays: marks.count)
    }

    /// The last `weeks` weeks as rows of seven (Monday first), ending with the current week.
    public static func calendarWeeks(plan: [TemplateDay], logs: [WorkoutLog], percents: [String: Int], _ now: Date, weeks: Int = 5, _ cal: Calendar = .current) -> [[DayCell]] {
        let today = Dates.localDate(now, cal)
        let byDate = Dictionary(grouping: logs, by: \.date)
        let thisMonday = Dates.monday(of: now, cal)
        return (0..<weeks).reversed().map { w in
            let monday = cal.date(byAdding: .day, value: -7 * w, to: thisMonday) ?? thisMonday
            return Dates.weekDates(monday, cal).map { d in
                let date = Dates.localDate(d, cal)
                let day = byDate[date] ?? []
                let handled = day.contains { l in l.skipped != true && (l.done == true || plan.contains { p in Plan.matches(l, p) && Plan.isComplete(l, p) }) }
                let trained: DayCell.Trained = handled ? .done : day.contains { Plan.loggedSets($0) > 0 } ? .part : day.contains { $0.skipped == true } ? .skipped : .none
                return DayCell(date: date, trained: trained, macroPct: percents[date], today: date == today, future: date > today)
            }
        }
    }
}
