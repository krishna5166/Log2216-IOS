import SwiftUI
import Fit2216Core

/// Every workout you logged, newest first. Open one to fix a number, relabel its unit, or delete it.
struct PastSessionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let sessions = model.logs.sorted { $0.date == $1.date ? ($0.dayIndex ?? 0) > ($1.dayIndex ?? 0) : $0.date > $1.date }
        List {
            ForEach(sessions, id: \.documentKey) { log in
                NavigationLink { PastSessionDetail(log: log) } label: { Row(log: log) }
            }
        }
        .overlay { if sessions.isEmpty { ContentUnavailableView("No workouts yet", systemImage: "dumbbell") } }
        .navigationTitle("Past sessions")
    }
}

private extension WorkoutLog {
    var documentKey: String { Logging.documentID(self) }
}

private struct Row: View {
    let log: WorkoutLog

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(log.dayName).font(.headline)
                Spacer()
                if log.skipped == true { Text("Skipped").font(.caption.bold()).foregroundStyle(.orange) }
                else if log.done == true { Text("Done").font(.caption.bold()).foregroundStyle(.green) }
            }
            Text("\(Format.date(log.date)) · \(Plan.loggedSets(log)) sets · \(Units.logUnit(log).rawValue)").font(.footnote).foregroundStyle(.secondary)
        }
    }
}

struct PastSessionDetail: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let log: WorkoutLog
    @State private var draft: WorkoutLog
    @State private var confirmDelete = false
    @State private var logging: LoggingTarget?
    @State private var copyProblem: String?

    init(log: WorkoutLog) {
        self.log = log
        _draft = State(initialValue: log)
    }

    private var names: [String] { draft.sets.keys.sorted() }

    var body: some View {
        List {
            Section {
                Picker("Weights typed in", selection: Binding(get: { Units.logUnit(draft) }, set: { draft.unit = $0 })) {
                    Text("kg").tag(WeightUnit.kg); Text("lb").tag(WeightUnit.lb)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Changing this only relabels the weights; the numbers are not converted. Use it if the unit was wrong.")
            }

            ForEach(names, id: \.self) { name in
                Section(Plan.effectiveName(draft, name)) {
                    ForEach(Array((draft.sets[name] ?? []).enumerated()), id: \.offset) { i, row in
                        if !row.weight.isEmpty || !row.reps.isEmpty {
                            HStack {
                                Text("Set \(i + 1)").foregroundStyle(.secondary)
                                Spacer()
                                TextField("weight", text: binding(name, i, weight: true)).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 70)
                                Text("×").foregroundStyle(.secondary)
                                TextField("reps", text: binding(name, i, weight: false)).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 50)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Delete this workout", role: .destructive) { confirmDelete = true }
            }
        }
        .navigationTitle(draft.dayName)
        .keyboardDoneButton()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { model.save(draft); dismiss() }.disabled(draft == log)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { repeatToday() } label: { Label("Repeat today", systemImage: "arrow.counterclockwise") }
                    if let text = WorkoutCopy.export(log: log, plan: model.plan) {
                        ShareLink(item: text) { Label("Share workout", systemImage: "square.and.arrow.up") }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Copy or share this workout")
            }
        }
        .fullScreenCover(item: $logging) { LoggingView(day: $0.day) }
        .alert("Can't copy yet", isPresented: Binding(get: { copyProblem != nil }, set: { if !$0 { copyProblem = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(copyProblem ?? "") }
        .confirmationDialog("Delete \(draft.dayName) on \(Format.date(draft.date))?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) { model.deleteLog(log); dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This can't be undone.") }
    }

    /// A fresh copy of this workout (its targets and swaps, no sets) for today.
    private func repeatToday() {
        guard let source = WorkoutCopy.sourceDay(for: log, plan: model.plan) else { copyProblem = "This workout has no exercises to copy."; return }
        switch model.startCopy(of: source, logged: log) {
        case .ready(let day): logging = LoggingTarget(day: day)
        case .blocked(let why): copyProblem = why
        }
    }

    private func binding(_ name: String, _ index: Int, weight: Bool) -> Binding<String> {
        Binding(
            get: { let r = draft.sets[name]?[index]; return (weight ? r?.weight : r?.reps) ?? "" },
            set: { let v = Logging.numeric($0, decimal: weight); draft = Logging.setting(draft, exercise: name, index: index, weight: weight ? v : nil, reps: weight ? nil : v) }
        )
    }
}
