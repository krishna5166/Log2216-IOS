import SwiftUI
import Charts
import Fit2216Core

/// A tiny trend line: a faint baseline through the middle, a light fill under the curve, no axes, labels or numbers.
struct Sparkline: View {
    let values: [Double?]

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                    p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                }
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                if pts.count >= 2 {
                    Path { p in
                        p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                        pts.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(Theme.lime.opacity(0.12))

                    Path { p in
                        p.move(to: pts[0])
                        pts.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(Theme.lime, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                    Circle().fill(Theme.lime).frame(width: 8, height: 8).position(pts[pts.count - 1])
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let present = values.enumerated().compactMap { i, v in v.map { (i, $0) } }
        guard let lo = present.map(\.1).min(), let hi = present.map(\.1).max(), values.count > 1 else { return [] }
        let span = max(hi - lo, 1)
        let pad: CGFloat = 8
        return present.map { i, v in
            CGPoint(x: size.width * CGFloat(i) / CGFloat(values.count - 1),
                    y: size.height - pad - (size.height - 2 * pad) * CGFloat((v - lo) / span))
        }
    }
}

/// The Insights headline: overall strength progress with a filter menu (Overall, Lower body, Upper body, then each muscle).
struct StrengthCard: View {
    let series: [StrengthSeries]
    @State private var filter: StrengthFilter = .overall

    private var current: StrengthSeries? { series.first { $0.filter == filter } ?? series.first }

    var body: some View {
        SectionCard("Strength") {
            if let current {
                HStack {
                    Menu {
                        ForEach(series, id: \.filter) { s in
                            Button { filter = s.filter } label: {
                                if s.filter == current.filter { Label(s.filter.label, systemImage: "checkmark") }
                                else { Text(s.filter.label + (s.enough ? "" : " (few sessions)")) }
                            }
                            .disabled(!s.enough)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(current.filter.label).font(.subheadline.weight(.semibold))
                            Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
                        }
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    Spacer()
                    if let change = change(current) {
                        BigValue(value: "\(change >= 0 ? "+" : "")\(Int(change.rounded()))%", color: change >= 0 ? Theme.lime : Theme.pink, size: 30)
                    }
                }
                if current.enough { chart(current) }
                else { Text("Not enough sessions yet to draw this line (need \(Strength.minSessions)).").font(.footnote).foregroundStyle(.secondary) }
            } else {
                Text("Log a few workouts with weights and your strength trend shows up here.").font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func change(_ s: StrengthSeries) -> Double? {
        guard s.enough, let last = s.weeks.compactMap(\.score).last, s.weeks.compactMap(\.score).count >= 2 else { return nil }
        return last - 100
    }

    private func chart(_ s: StrengthSeries) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                RuleMark(y: .value("Start", 100)).foregroundStyle(Color.white.opacity(0.18)).lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                ForEach(s.weeks.filter { $0.volumeIndex != nil }, id: \.start) { w in
                    if let d = Dates.parse(w.start), let v = w.volumeIndex {
                        LineMark(x: .value("Week", d), y: .value("Index", v), series: .value("Metric", "Volume"))
                            .foregroundStyle(Theme.lime).lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round)).interpolationMethod(.catmullRom)
                    }
                }
                ForEach(s.weeks.filter { $0.e1rmIndex != nil }, id: \.start) { w in
                    if let d = Dates.parse(w.start), let e = w.e1rmIndex {
                        LineMark(x: .value("Week", d), y: .value("Index", e), series: .value("Metric", "Est. max"))
                            .foregroundStyle(Theme.cyan).lineStyle(StrokeStyle(lineWidth: 1.5)).interpolationMethod(.catmullRom)
                    }
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()).foregroundStyle(.secondary) } }
            .chartYAxis(.hidden)
            .frame(height: 170)
            HStack(spacing: 14) {
                Label("Volume", systemImage: "circle.fill").foregroundStyle(Theme.lime)
                Label("Estimated max", systemImage: "circle.fill").foregroundStyle(Theme.cyan)
            }
            .font(.caption2)
            Text("Both lines start at 100 and show change since your first logged week in this window.").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
