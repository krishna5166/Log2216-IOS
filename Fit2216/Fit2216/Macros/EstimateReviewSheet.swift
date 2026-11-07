import SwiftUI
import Fit2216Core

/// Check and correct an estimate before it is saved: change any name or amount, remove a food, see the total.
struct EstimateReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let review: MacrosModel.Review
    let replacing: Bool
    let save: ([Meal]) -> Void
    let cancel: () -> Void

    private struct Row: Identifiable {
        let id = UUID()
        var meal: Meal
    }

    @State private var rows: [Row]

    init(review: MacrosModel.Review, replacing: Bool, save: @escaping ([Meal]) -> Void, cancel: @escaping () -> Void) {
        self.review = review
        self.replacing = replacing
        self.save = save
        self.cancel = cancel
        _rows = State(initialValue: review.items.map { Row(meal: $0) })
    }

    private var cleaned: [Meal] { Food.cleaned(rows.map(\.meal)) }
    private var totals: Totals { Food.totals(cleaned) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Label(review.fromMemory ? "From an earlier estimate or correction on this phone" : "Estimated by AI from your text",
                          systemImage: review.fromMemory ? "clock.arrow.circlepath" : "sparkles")
                        .font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                    Text("\u{201C}\(review.text)\u{201D}").font(.subheadline).foregroundStyle(.secondary).lineLimit(4)

                    ForEach($rows) { $row in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                TextField("Food", text: $row.meal.name).font(.headline)
                                Button { rows.removeAll { $0.id == row.id } } label: { Image(systemName: "trash") }
                                    .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Remove \(row.meal.name)")
                            }
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                field("Calories", unit: "kcal", value: $row.meal.kcal, tint: Theme.pink)
                                field("Protein", unit: "g", value: $row.meal.protein, tint: Theme.lime)
                                field("Carbs", unit: "g", value: $row.meal.carbs, tint: Theme.cyan)
                                field("Fat", unit: "g", value: $row.meal.fat, tint: Theme.purple)
                            }
                        }
                        .card()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Total").font(.title3.weight(.semibold))
                        HStack(spacing: 14) {
                            BigValue(value: "\(Int(totals.kcal.rounded()))", unit: "kcal", color: Theme.pink, size: 26)
                            BigValue(value: "\(Int(totals.protein.rounded()))", unit: "p", color: Theme.lime, size: 22)
                            BigValue(value: "\(Int(totals.carbs.rounded()))", unit: "c", color: Theme.cyan, size: 22)
                            BigValue(value: "\(Int(totals.fat.rounded()))", unit: "f", color: Theme.purple, size: 22)
                        }
                        Text("Estimates, not measurements. Fix anything that looks off before saving.").font(.footnote).foregroundStyle(.secondary)
                    }
                    .card()

                    Button { save(rows.map(\.meal)); dismiss() } label: { Text(replacing ? "Update meal" : "Save meal").limeCapsule(height: 54, enabled: !cleaned.isEmpty) }
                        .buttonStyle(.plain)
                        .disabled(cleaned.isEmpty)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .keyboardDoneButton()
            .navigationTitle("Check estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { cancel(); dismiss() } } }
        }
        .interactiveDismissDisabled() // leaving must be a choice: Save or Cancel
    }

    private func field(_ label: String, unit: String, value: Binding<Double>, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(label) (\(unit))").font(.caption).foregroundStyle(.secondary)
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(tint)
                .padding(10)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("\(label), \(unit)")
        }
    }
}
