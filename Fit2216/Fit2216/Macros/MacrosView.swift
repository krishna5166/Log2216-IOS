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
                loadRow
                tiles(totals: totals, targets: targets)
                if targets == nil {
                    Text("Fill in Body and targets (profile icon, then Settings) to see targets here.").font(.footnote).foregroundStyle(.secondary)
                }
                if !macros.cards.isEmpty { entries }
                editor(targets: targets).disabled(!macros.loaded)
                if !smartNotes { consent }
                Text("Estimates from what you write, not medical advice. Each entry becomes a card; tap a card to edit just that entry.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(item: $macros.review) { review in
            EstimateReviewSheet(review: review, replacing: macros.editing != nil, save: { items in
                guard let uid = model.uid else { return }
                macros.confirmReview(items, uid: uid, targets: model.targets, service: model.firestore)
            }, cancel: { macros.cancelReview() })
        }
        .navigationTitle("Macros")
        .task(id: Dates.localDate(model.now)) {
            macros.track = { write in model.tracked(write) }
            guard let uid = model.uid else { return }
            await macros.load(uid: uid, date: Dates.localDate(model.now), service: model.firestore)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, let uid = model.uid { macros.saveDraft(uid: uid, targets: targets, service: model.firestore) }
        }
        .onChange(of: model.targets) { _, newTargets in
            // targets can arrive after the screen opens: keep today's completion % in step
            if macros.loaded, let uid = model.uid { macros.saveDraft(uid: uid, targets: newTargets, service: model.firestore) }
        }
        .onDisappear {
            if let uid = model.uid { macros.saveDraft(uid: uid, targets: model.targets, service: model.firestore) }
        }
    }

    // MARK: pieces

    @ViewBuilder private var loadRow: some View {
        if let error = macros.loadError {
            VStack(alignment: .leading, spacing: 6) {
                Text("Couldn't load today's food: \(error)").font(.footnote).foregroundStyle(.secondary)
                Button("Retry") { Task { await reloadDay() } }.font(.footnote.bold())
            }
        } else if !macros.loaded {
            HStack(spacing: 8) { ProgressView(); Text("Loading today's food…").font(.footnote).foregroundStyle(.secondary) }
        }
    }

    private func reloadDay() async {
        guard let uid = model.uid else { return }
        await macros.load(uid: uid, date: Dates.localDate(model.now), service: model.firestore)
    }

    /// Four rings (calories, protein, carbs, fat) and the numbers beside them, like Fitness's Activity Rings.
    private func tiles(totals: Totals, targets: Targets?) -> some View {
        let rows: [(MacroKey, String, String, Color)] = [
            (.kcal, "Calories", "kcal", Theme.pink), (.protein, "Protein", "g", Theme.lime),
            (.carbs, "Carbs", "g", Theme.cyan), (.fat, "Fat", "g", Theme.purple),
        ]
        func value(_ key: MacroKey) -> Double {
            switch key { case .kcal: return totals.kcal; case .protein: return totals.protein; case .carbs: return totals.carbs; case .fat: return totals.fat }
        }
        return HStack(alignment: .center, spacing: 18) {
            ZStack {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    let status = Food.status(row.0, value: value(row.0), targets: targets)
                    let progress = status.target.map { $0 > 0 ? value(row.0) / Double($0) : 0 } ?? 0
                    Ring(progress: progress, color: row.3, size: 138 - CGFloat(i) * 30, line: 11)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rows, id: \.0) { key, label, unit, tint in
                    let v = value(key)
                    let status = Food.status(key, value: v, targets: targets)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 6) {
                            Text(label).font(.footnote)
                            Text(note(status, unit: unit)).font(.caption2).foregroundStyle(color(status.state))
                        }
                        BigValue(value: "\(Int(v.rounded()))" + (status.target.map { "/\($0)" } ?? ""), unit: unit, color: tint, size: 22)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rows.map { key, label, unit, _ in
            let v = Int(value(key).rounded())
            let status = Food.status(key, value: value(key), targets: targets)
            return "\(label): \(v)" + (status.target.map { " of \($0)" } ?? "") + " \(unit)."
        }.joined(separator: " "))
    }

    private func color(_ s: MacroStatus.State) -> Color {
        switch s { case .hit: return Theme.lime; case .over: return Theme.pink; case .under: return .orange; case .none: return .secondary }
    }

    private func note(_ s: MacroStatus, unit: String) -> String {
        switch s.state {
        case .hit: return "✓ on target"
        case .under: return "\(s.delta) \(unit) to go"
        case .over: return "\(-s.delta) \(unit) over"
        case .none: return ""
        }
    }

    private var entries: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today").font(.title3.weight(.semibold))
            ForEach(macros.cards) { card in
                let t = card.totals
                Button { macros.open(card) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(card.title).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundStyle(.primary)
                        HStack(spacing: 10) {
                            BigValue(value: "\(Int(t.kcal.rounded()))", unit: "kcal", color: Theme.pink, size: 20)
                            Text("P \(Int(t.protein.rounded()))").foregroundStyle(Theme.lime)
                            Text("C \(Int(t.carbs.rounded()))").foregroundStyle(Theme.cyan)
                            Text("F \(Int(t.fat.rounded()))").foregroundStyle(Theme.purple)
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                    .overlay { if macros.editing == card.id { RoundedRectangle(cornerRadius: 18).stroke(Theme.lime, lineWidth: 2) } }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit entry: \(card.title)")
            }
        }
    }

    private func editor(targets: Targets?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(macros.editing == nil ? "Add what you ate" : "Edit entry").font(.title3.weight(.semibold))
            TextEditor(text: $macros.text)
                .frame(minHeight: macros.editing == nil ? 96 : 130)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    if macros.text.isEmpty { Text("Breakfast: 2 eggs, toast with butter").foregroundStyle(.tertiary).padding(16).allowsHitTesting(false) }
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
                let canSubmit = !macros.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && macros.status != .parsing && smartNotes
                Button {
                    guard let uid = model.uid else { return }
                    Task { await macros.submit(uid: uid, targets: targets, service: model.firestore) }
                } label: {
                    Text(buttonTitle).font(.headline).foregroundStyle(.black)
                        .padding(.horizontal, 22).frame(height: 46)
                        .background(Theme.lime, in: Capsule())
                        .opacity(canSubmit ? 1 : 0.35)
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
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
