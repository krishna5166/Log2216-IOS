import SwiftUI
import Fit2216Core

/// The whole week: tap a day to edit it. Changes are saved when you press Done on a day.
struct PlanEditorView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: EditTarget?

    private struct EditTarget: Identifiable { let day: TemplateDay; var id: Int { day.day } }

    private var weekdays: [Int] { [1, 2, 3, 4, 5, 6, 0] }

    var body: some View {
        List {
            if model.plan.isEmpty {
                Section {
                    Text("You have no plan yet. Start from the starter plan, or add days one by one.").font(.footnote).foregroundStyle(.secondary)
                    Button("Use the starter plan") { model.savePlan(SampleData.plan) }
                }
            }
            Section("Week") {
                ForEach(weekdays, id: \.self) { weekday in
                    if let day = model.plan.first(where: { $0.day == weekday }) {
                        Button { editing = EditTarget(day: day) } label: { DayLine(weekday: weekday, day: day) }
                            .foregroundStyle(.primary)
                    } else {
                        Button { editing = EditTarget(day: TemplateDay(day: weekday, name: "Rest", type: .rest)) } label: {
                            HStack {
                                Text(Calendar.current.weekdaySymbols[weekday]).foregroundStyle(.secondary)
                                Spacer()
                                Text("Add").font(.footnote.bold())
                            }
                        }
                    }
                }
            }
            Section {
                Text("Renaming an exercise starts a fresh history for that lift. Past workouts keep the old name.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            NavigationStack {
                DayEditorView(day: target.day) { saved in
                    var next = model.plan.filter { $0.day != saved.day }
                    next.append(saved)
                    model.savePlan(Plan.sort(next))
                }
            }
        }
    }
}

private struct DayLine: View {
    let weekday: Int
    let day: TemplateDay

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Calendar.current.weekdaySymbols[weekday]).font(.caption).textCase(.uppercase).foregroundStyle(.secondary)
            Text(day.name).font(.headline)
            Text(day.type == .rest || day.exercises.isEmpty ? "Rest" : "\(day.exercises.count) exercises · \(Plan.plannedSets(day)) sets")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}

/// One day: its name, type, notes and exercises (reorder, remove, add).
struct DayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: TemplateDay
    let onSave: (TemplateDay) -> Void

    init(day: TemplateDay, onSave: @escaping (TemplateDay) -> Void) {
        _draft = State(initialValue: day)
        self.onSave = onSave
    }

    private var problem: String? {
        let names = draft.exercises.map { $0.name.trimmingCharacters(in: .whitespaces) }
        if names.contains("") { return "Every exercise needs a name." }
        if Set(names).count != names.count { return "Two exercises have the same name." }
        return nil
    }

    var body: some View {
        Form {
            Section(Calendar.current.weekdaySymbols[draft.day]) {
                TextField("Day name", text: $draft.name)
                Picker("Type", selection: $draft.type) {
                    Text("Strength").tag(DayType.strength)
                    Text("Hypertrophy").tag(DayType.hypertrophy)
                    Text("Rest").tag(DayType.rest)
                }
                TextField("Notes (optional)", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0.isEmpty ? nil : $0 }), axis: .vertical)
            }

            Section("Exercises") {
                ForEach(draft.exercises.indices, id: \.self) { i in
                    NavigationLink {
                        ExerciseEditorView(exercise: $draft.exercises[i])
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.exercises[i].name.isEmpty ? "New exercise" : draft.exercises[i].name).font(.headline)
                            Text("\(draft.exercises[i].sets) × \(draft.exercises[i].reps)" + (draft.exercises[i].optional == true ? " · optional" : ""))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { draft.exercises.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { draft.exercises.remove(atOffsets: $0) }
                Button { draft.exercises.append(TemplateExercise(name: "", sets: 3, reps: "8–12")) } label: { Label("Add exercise", systemImage: "plus") }
            }

            if let problem { Section { Text(problem).foregroundStyle(.red).font(.footnote) } }
        }
        .navigationTitle(draft.name.isEmpty ? "Day" : draft.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    var saved = draft
                    saved.name = saved.name.trimmingCharacters(in: .whitespaces)
                    for i in saved.exercises.indices { saved.exercises[i].name = saved.exercises[i].name.trimmingCharacters(in: .whitespaces) }
                    onSave(saved)
                    dismiss()
                }
                .disabled(problem != nil || draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ToolbarItem(placement: .bottomBar) { EditButton() }
        }
    }
}

/// One exercise: name, sets, reps, rest, optional, alternatives and which muscles it works.
struct ExerciseEditorView: View {
    @Binding var exercise: TemplateExercise
    @State private var newAlternative = ""

    var body: some View {
        Form {
            Section {
                TextField("Exercise", text: $exercise.name)
                Stepper("Sets: \(exercise.sets)", value: $exercise.sets, in: 1...100)
                HStack { Text("Reps"); Spacer(); TextField("8–12", text: $exercise.reps).multilineTextAlignment(.trailing).frame(width: 100) }
                HStack {
                    Text("Rest (seconds)")
                    Spacer()
                    TextField("\(Plan.restSeconds(TemplateExercise(name: exercise.name, sets: exercise.sets, reps: exercise.reps)))", text: Binding(
                        get: { exercise.restSec.map(String.init) ?? "" },
                        set: { exercise.restSec = Int($0).map { max(10, min(600, $0)) } }
                    ))
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 100)
                }
                Toggle("Optional", isOn: Binding(get: { exercise.optional == true }, set: { exercise.optional = $0 ? true : nil }))
            }

            Section("Alternatives") {
                ForEach(exercise.alternatives ?? [], id: \.self) { alt in Text(alt) }
                    .onDelete { offsets in
                        var list = exercise.alternatives ?? []
                        list.remove(atOffsets: offsets)
                        exercise.alternatives = list.isEmpty ? nil : list
                    }
                HStack {
                    TextField("Add an alternative", text: $newAlternative).onSubmit(addAlternative)
                    Button("Add", action: addAlternative).disabled(newAlternative.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(Muscle.allCases, id: \.self) { m in
                        let on = exercise.muscles?.contains(m) == true
                        Button {
                            var list = exercise.muscles ?? []
                            if on { list.removeAll { $0 == m } } else { list.append(m) }
                            exercise.muscles = list.isEmpty ? nil : list
                        } label: {
                            Text(m.label).font(.footnote).frame(maxWidth: .infinity).padding(.vertical, 6)
                                .background(on ? Color.accentColor : Color.secondary.opacity(0.15), in: Capsule())
                                .foregroundStyle(on ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text("Muscles worked")
            } footer: {
                if exercise.muscles?.isEmpty ?? true {
                    let guess = Muscles.forName(exercise.name).primary.map(\.label).joined(separator: ", ")
                    Text("Guessed from the name: \(guess.isEmpty ? "none yet" : guess). Choose muscles to override.")
                }
            }
        }
        .navigationTitle(exercise.name.isEmpty ? "New exercise" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func addAlternative() {
        let v = newAlternative.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        var list = exercise.alternatives ?? []
        if !list.contains(v) { list.append(v) }
        exercise.alternatives = list
        newAlternative = ""
    }
}
