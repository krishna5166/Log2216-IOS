import SwiftUI
import Charts
import Fit2216Core

/// Body weight over time: raw weigh-ins as dots, a smoothed 7-day line, a dashed target line, the area between them tinted
/// (green on the right side of the goal, red on the wrong side), and a short dotted stub showing where the current pace leads.
struct WeightChart: View {
    let entries: [WeightEntry]       // oldest first
    let unit: WeightUnit
    let baselineKg: Double?
    let goal: Goal?

    private func date(_ s: String) -> Date { Dates.parse(s) ?? Date() }
    private func shown(_ kg: Double) -> Double { Units.fromKg(kg, to: unit) }

    var body: some View {
        let average = Insights.movingAverage(entries)
        let segments = baselineKg.map { base in
            Insights.splitByBaseline(average.map { .init(t: date($0.date).timeIntervalSince1970, v: shown($0.kg)) }, baseline: shown(base))
        } ?? []
        let stub = projectionStub(average: average)

        Chart {
            ForEach(Array(segments.enumerated()), id: \.offset) { i, segment in
                ForEach(Array(segment.pts.enumerated()), id: \.offset) { _, p in
                    AreaMark(x: .value("Date", Date(timeIntervalSince1970: p.t)),
                             yStart: .value("Target", shown(baselineKg ?? 0)), yEnd: .value("Weight", p.v), series: .value("Stretch", i))
                        .foregroundStyle(Insights.baselineTone(above: segment.above, goal: goal) == .good ? Color.green.opacity(0.25) : Color.red.opacity(0.25))
                }
            }
            if let baselineKg {
                RuleMark(y: .value("Target", shown(baselineKg)))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.secondary)
                    .annotation(position: .top, alignment: .trailing) { Text("Target").font(.caption2).foregroundStyle(.secondary) }
            }
            ForEach(entries, id: \.date) { e in
                PointMark(x: .value("Date", date(e.date)), y: .value("Weight", shown(e.kg)))
                    .symbolSize(18).foregroundStyle(.secondary.opacity(0.6))
            }
            ForEach(average, id: \.date) { e in
                LineMark(x: .value("Date", date(e.date)), y: .value("Weight", shown(e.kg)), series: .value("Line", "avg"))
                    .interpolationMethod(.catmullRom).foregroundStyle(.primary)
            }
            if let stub {
                ForEach(Array(stub.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Date", p.0), y: .value("Weight", p.1), series: .value("Line", "pace"))
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 5])).foregroundStyle(.secondary)
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 200)
        .accessibilityLabel("Body weight chart")
    }

    /// A short dotted line past the latest average, following the real 4-week pace; stops where it would cross the target.
    private func projectionStub(average: [WeightEntry]) -> [(Date, Double)]? {
        guard let last = average.last, let trend = Insights.weightTrend(entries, Date()), let first = entries.first else { return nil }
        let start = date(last.date)
        let span = max(1, Double(Dates.daysBetween(date(first.date), start)))
        let days = min(max(span * 0.22, 7), 21)
        var endDays = days
        let perDay = shown(trend.perWeek + last.kg) - shown(last.kg) // pace in the display unit per week
        let slope = perDay / 7
        if let base = baselineKg, slope != 0 {
            let toBase = (shown(base) - shown(last.kg)) / slope
            if toBase > 0 && toBase < days { endDays = toBase }
        }
        guard let end = Calendar.current.date(byAdding: .day, value: Int(endDays.rounded(.up)), to: start) else { return nil }
        return [(start, shown(last.kg)), (end, shown(last.kg) + slope * endDays)]
    }
}
