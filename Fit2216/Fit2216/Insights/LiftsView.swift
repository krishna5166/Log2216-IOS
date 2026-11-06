import SwiftUI
import Fit2216Core

/// Every lift you have logged twice or more.
struct LiftsListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let lifts = Insights.liftHistory(model.logs).filter { $0.value.count >= 2 }.sorted { $0.value.count > $1.value.count }
        List(lifts, id: \.key) { name, points in
            NavigationLink { LiftDetailView(name: name, points: points) } label: {
                HStack {
                    Text(name)
                    Spacer()
                    Text("\(points.count) sessions").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .overlay { if lifts.isEmpty { ContentUnavailableView("No lifts with two sessions yet", systemImage: "chart.line.uptrend.xyaxis") } }
        .navigationTitle("Lifts")
    }
}

struct LiftDetailView: View {
    @Environment(AppModel.self) private var model
    let name: String
    let points: [LiftPoint]

    var body: some View {
        let unit = model.profile.gymUnit
        List {
            Section("Estimated max") { LiftChart(points: points, unit: unit) }
            Section("Best set each session") {
                ForEach(points.reversed(), id: \.date) { p in
                    HStack {
                        Text(Format.date(p.date))
                        Spacer()
                        Text("\(Format.weight(kg: p.weight, unit: unit)) × \(Int(p.reps))").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
