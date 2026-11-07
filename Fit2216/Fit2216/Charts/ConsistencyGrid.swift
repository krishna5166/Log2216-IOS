import SwiftUI
import Fit2216Core

/// The last five weeks as a calendar: lime = workout done, outlined = partly done, orange = skipped, and a dot for the days you hit your food targets.
struct ConsistencyGrid: View {
    let weeks: [[DayCell]]
    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                ForEach(0..<7, id: \.self) { i in Text(Self.letters[i]).font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, row in
                HStack {
                    ForEach(row, id: \.date) { cell in
                        ZStack {
                            Circle().fill(fill(cell)).frame(width: 26, height: 26)
                            if cell.trained == .part { Circle().stroke(Theme.lime, lineWidth: 2).frame(width: 26, height: 26) }
                            if cell.today { Circle().stroke(Color.primary, lineWidth: 2).frame(width: 30, height: 30) }
                            if let pct = cell.macroPct, pct >= 75 { Circle().fill(Theme.cyan).frame(width: 6, height: 6).offset(x: 10, y: -10) }
                        }
                        .frame(maxWidth: .infinity)
                        .opacity(cell.future ? 0.35 : 1)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Consistency calendar, last five weeks")
    }

    private func fill(_ c: DayCell) -> Color {
        switch c.trained {
        case .done: return Theme.lime
        case .skipped: return .orange.opacity(0.7)
        case .part: return Theme.lime.opacity(0.15)
        case .none: return Color.secondary.opacity(0.15)
        }
    }
}
