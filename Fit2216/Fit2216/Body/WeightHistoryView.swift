import SwiftUI
import Fit2216Core

/// Every weigh-in, newest first, with delete.
struct WeightHistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            ForEach(model.weights, id: \.date) { w in
                HStack {
                    Text(Format.date(w.date))
                    Spacer()
                    Text(Format.weight(kg: w.kg, unit: model.profile.bodyUnit)).foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                let dates = offsets.map { model.weights[$0].date }
                for d in dates { model.deleteWeight(date: d) }
            }
        }
        .navigationTitle("Weigh-ins")
        .overlay { if model.weights.isEmpty { ContentUnavailableView("No weigh-ins yet", systemImage: "scalemass") } }
    }
}
