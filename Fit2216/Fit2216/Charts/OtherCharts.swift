import SwiftUI
import Charts
import Fit2216Core

/// Estimated max for one lift over time.
struct LiftChart: View {
    let points: [LiftPoint]
    let unit: WeightUnit

    var body: some View {
        Chart(points, id: \.date) { p in
            LineMark(x: .value("Date", Dates.parse(p.date) ?? Date()), y: .value("Estimated max", Units.fromKg(p.e1rm, to: unit)))
                .interpolationMethod(.catmullRom)
            PointMark(x: .value("Date", Dates.parse(p.date) ?? Date()), y: .value("Estimated max", Units.fromKg(p.e1rm, to: unit)))
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 180)
        .accessibilityLabel("Estimated max over time")
    }
}

/// Finished workouts per week.
struct WeeklyWorkoutsChart: View {
    let weeks: [WeekStat]

    var body: some View {
        Chart(weeks, id: \.start) { w in
            BarMark(x: .value("Week", Dates.parse(w.start) ?? Date(), unit: .weekOfYear), y: .value("Workouts", w.workouts))
                .foregroundStyle(Color.accentColor)
        }
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .frame(height: 140)
        .accessibilityLabel("Workouts per week")
    }
}

/// Last 7 days of food: how much of each day's calorie and macro targets you hit.
struct MacroDaysChart: View {
    let days: [(date: String, pct: Int?)]

    var body: some View {
        let first = days.first.flatMap { Dates.parse($0.date) } ?? Date()
        let last = days.last.flatMap { Dates.parse($0.date) } ?? Date()
        Chart {
            ForEach(days, id: \.date) { d in
                if let pct = d.pct {
                    BarMark(x: .value("Day", Dates.parse(d.date) ?? Date(), unit: .day), y: .value("Hit", pct))
                        .foregroundStyle(pct >= 75 ? Theme.lime : Color.white.opacity(0.35))
                }
            }
            RuleMark(y: .value("Good day", 75)).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(.secondary)
        }
        .chartYScale(domain: 0...100)
        .chartXScale(domain: first...Calendar.current.date(byAdding: .day, value: 1, to: last)!)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .frame(height: 140)
        .accessibilityLabel("Food targets hit, last 7 days")
    }
}
