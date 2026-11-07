import SwiftUI
import Fit2216Core

/// Shown when you finish a workout, like Fitness's summary: time, sets, volume and any personal bests.
struct WorkoutCompleteView: View {
    let result: WorkoutResult
    let elapsed: TimeInterval
    let unit: WeightUnit
    let done: () -> Void

    private var volume: String { Int(Units.fromKg(result.volumeKg, to: unit).rounded()).formatted() }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(Theme.lime)
                Text("Workout complete").font(.system(size: 34, weight: .bold, design: .rounded))
            }
            .padding(.top, 40)

            metric("Time", BigValue(value: Plan.clock(max(0, elapsed)), color: .yellow, size: 56))
            metric("Sets", BigValue(value: "\(result.sets)", unit: result.sets == 1 ? "set" : "sets", color: Theme.pink, size: 56))
            metric("Total weight lifted", BigValue(value: volume, unit: unit.rawValue, color: Theme.lime, size: 56))

            if !result.records.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PERSONAL BESTS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(result.records, id: \.self) { name in
                        Label(name, systemImage: "trophy.fill").font(.headline).foregroundStyle(.orange)
                    }
                }
            }

            Spacer(minLength: 0)
            Button(action: done) { Text("Done").limeCapsule() }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func metric(_ label: String, _ value: BigValue) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            value
            Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
