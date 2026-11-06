import SwiftUI
import Fit2216Core

/// Log a weigh-in for today or an earlier day. The newest one also keeps your body details (and so your targets) current.
struct WeighInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @State private var text = ""
    @State private var date = Date()

    private var unit: WeightUnit { model.profile.bodyUnit }
    private var entered: Double? { Double(text.replacingOccurrences(of: ",", with: ".")).flatMap { $0 > 0 && $0 < 1000 ? $0 : nil } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Weight", text: $text).keyboardType(.decimalPad)
                        Text(unit.rawValue).foregroundStyle(.secondary)
                    }
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                }
                if let last = model.weights.first {
                    Section("Last logged") { Text("\(Format.weight(kg: last.kg, unit: unit)) on \(Format.date(last.date))") }
                }
            }
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let value = entered else { return }
                        let kg = (Units.toKg(value, from: unit) * 100).rounded() / 100
                        model.saveWeight(WeightEntry(date: Dates.localDate(date), kg: kg))
                        dismiss()
                    }
                    .disabled(entered == nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
