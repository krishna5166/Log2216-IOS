import SwiftUI
import Fit2216Core

struct MacrosView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("smartNotes") private var smartNotes = false
    @State private var macros = MacrosModel()

    var body: some View {
        let targets = model.targets
        let totals = macros.totals

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tiles(totals: totals, targets: targets)
                if targets == nil {
                    Text("Fill in Body and targets (profile icon, then Settings) to see targets here.").font(.footnote).foregroundStyle(.secondary)
                }
                if !macros.cards.isEmpty { entries }
                editor(targets: targets)
                if !smartNotes { consent }
                Text("Estimates from what you write, not medical advice. Each entry becomes a card; tap a card to edit just that entry.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Macros")
        .task(id: Dates.localDate(model.now)) {
            guard let uid = model.uid else { return }
            await macros.load(uid: uid, date: Dates.localDate(model.now), service: model.firestore)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, let uid = model.uid { macros.saveDraft(uid: uid, targets: targets, service: model.firestore) }
        }
        .onDisappear {
            if let uid = model.uid { macros.saveDraft(uid: uid, targets: model.targets, service: model.firestore) }
        }
    }

    // MARK: pieces

    private func tiles(totals: Totals, targets: Targets?) -> some View {
        let rows: [(MacroKey, String, String)] = [(.kcal, "Calories", "kcal"), (.protein, "Protein", "g"), (.carbs, "Carbs", "g"), (.fat, "Fat", "g")]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(rows, id: \.0) { key, label, unit in
                let value: Double = { switch key { case .kcal: return totals.kcal; case .protein: return totals.protein; case .carbs: return totals.carbs; case .fat: return totals.fat } }()
                let status = Food.status(key, value: value, targets: targets)
                let targetText = status.target.map { " / \($0)" } ?? ""
                VStack(alignment: .leading, spacing: 6) {
                    Text(label).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
                    Text("\(Int(value.rounded()))\(targetText) \(unit)").font(.headline)
                    if let target = status.target {
                        ProgressView(value: min(value, Double(target)), total: Double(target)).tint(color(status.state))
                    }
                    Text(note(status, unit: unit)).font(.caption).foregroundStyle(color(status.state))
                }
                .card()
            }
        }
    }

    private func color(_ s: MacroStatus.State) -> Color {
        switch s { case .hit: return .green; case .over: return .red; case .under: return .orange; case .none: return .secondary }
    }

    private func note(_ s: MacroStatus, unit: String) -> String {
        switch s.state {
        case .hit: return "✓ on target"
        case .under: return "\(s.delta) \(unit) to go"
        case .over: return "\(-s.delta) \(unit) over"
        case .none: return " "
        }
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today").font(.headline)
            ForEach(macros.cards) { card in
                let t = card.totals
                Button { macros.open(card) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title).font(.subheadline.bold()).foregroundStyle(.primary)
                        Text("\(Int(t.kcal.rounded())) kcal · P\(Int(t.protein.rounded())) C\(Int(t.carbs.rounded())) F\(Int(t.fat.rounded()))")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(macros.editing == card.id ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit entry: \(card.title)")
            }
        }
    }

    private func editor(targets: Targets?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(macros.editing == nil ? "Add what you ate" : "Edit entry").font(.headline)
            TextEditor(text: $macros.text)
                .frame(minHeight: macros.editing == nil ? 96 : 130)
                .padding(6)
                .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .topLeading) {
                    if macros.text.isEmpty { Text("Breakfast: 2 eggs, toast with butter").foregroundStyle(.tertiary).padding(14).allowsHitTesting(false) }
                }
                .disabled(macros.status == .parsing)
            HStack {
                statusText
                Spacer()
                if macros.editing != nil {
                    Button("Cancel") { macros.cancelEdit() }
                    Button("Remove", role: .destructive) {
                        if let uid = model.uid { macros.removeEditing(uid: uid, targets: targets, service: model.firestore) }
                    }
                }
                Button(buttonTitle) {
                    guard let uid = model.uid else { return }
                    Task { await macros.submit(uid: uid, targets: targets, service: model.firestore) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(macros.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || macros.status == .parsing || !smartNotes)
            }
        }
    }

    private var buttonTitle: String {
        if case .failed = macros.status { return "Retry" }
        return macros.editing == nil ? "Add meal" : "Update meal"
    }

    @ViewBuilder private var statusText: some View {
        switch macros.status {
        case .idle: EmptyView()
        case .parsing: HStack(spacing: 6) { ProgressView(); Text("Calculating…").font(.footnote).foregroundStyle(.secondary) }
        case .failed(let why): Text("Couldn't calculate: \(why). Your text is saved.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var consent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calculating uses AI. Your food text is sent through your own server to Google.").font(.footnote).foregroundStyle(.secondary)
            Button("Turn on AI calculation") { smartNotes = true }.font(.footnote.bold())
        }
    }
}

#Preview {
    NavigationStack { MacrosView() }.environment(AppModel.sample())
}
