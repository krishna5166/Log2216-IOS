import SwiftUI
import UIKit
import Fit2216Core

/// Which workout to open, so a cover can be presented for it.
struct LoggingTarget: Identifiable {
    let day: TemplateDay
    var id: Int { day.day }
}

/// The workout screen: one exercise at a time, sets with steppers, a rest timer, Previous and Next.
struct LoggingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @Environment(RestTimer.self) private var timer

    let day: TemplateDay
    @State private var session: LoggingSession?

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    ExerciseScreen(session: session)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(day.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                        .accessibilityLabel("Back to Home")
                }
            }
        }
        .onAppear(perform: start)
    }

    private func start() {
        guard session == nil else { return }
        let date = Dates.localDate(model.now)
        let log = Logging.open(day: day, date: date, existing: model.logs, gymUnit: model.profile.gymUnit)
        let followed = Logging.day(for: log, plan: model.plan, fallback: day)
        session = LoggingSession(day: followed, log: log, history: model.logs, timer: timer) { model.save($0) }
        RestTimer.requestPermission()
    }
}

private struct ExerciseScreen: View {
    @Environment(\.dismiss) private var dismiss
    let session: LoggingSession
    @State private var showList = false
    @State private var showSwap = false
    @State private var confirmSkip = false

    var body: some View {
        let e = session.exercise
        let rows = session.rows()

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.shownName).font(.title.bold())
                    Text("\(e.sets) × \(e.reps) reps · \(session.loggedCount) of \(e.sets) done" + (e.optional == true ? " · optional" : ""))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if session.isSwapped { Text("Swapped today from \(e.name)").font(.footnote).foregroundStyle(.secondary) }
                    ProgressView(value: Double(session.loggedCount), total: Double(max(e.sets, 1)))
                }

                if let last = session.lastTime {
                    HStack {
                        Text("Last: \(Plan.formatSets(last.sets, unit: session.unit)) · \(Format.date(last.date))")
                            .font(.footnote).foregroundStyle(.secondary)
                        Spacer()
                    }
                }

                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    SetRow(session: session, index: i, row: row)
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { BottomBar(session: session, showList: $showList, close: { dismiss() }) }
        .sheet(isPresented: $showList) { ExerciseListSheet(session: session) }
        .sheet(isPresented: $showSwap) { SwapSheet(session: session) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showSwap = true } label: { Label("Swap exercise", systemImage: "arrow.triangle.2.circlepath") }
                    Button { session.finish(); dismiss() } label: { Label("Finish workout", systemImage: "checkmark.circle") }
                    Button(role: .destructive) { confirmSkip = true } label: { Label("Skip this workout", systemImage: "forward") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("More")
            }
        }
        .confirmationDialog("Skip \(session.day.name) today?", isPresented: $confirmSkip, titleVisibility: .visible) {
            Button("Skip workout", role: .destructive) { session.skipWorkout(); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

private struct SetRow: View {
    let session: LoggingSession
    let index: Int
    let row: SetLog

    private var logged: Bool { Plan.filled(row) }

    var body: some View {
        let hint = session.hint(for: index)
        let step = Logging.step(session.unit)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(index + 1)").font(.headline).frame(width: 22)
                StepperField(
                    placeholder: session.unit.rawValue,
                    text: Binding(get: { row.weight }, set: { session.set(index, weight: $0) }),
                    keyboard: .decimalPad,
                    minus: { session.set(index, weight: Plan.step(row.weight, fallback: Double(hint?.weight ?? "") ?? 0, delta: -step)) },
                    plus: { session.set(index, weight: Plan.step(row.weight, fallback: Double(hint?.weight ?? "") ?? 0, delta: step)) }
                )
                StepperField(
                    placeholder: "reps",
                    text: Binding(get: { row.reps }, set: { session.set(index, reps: $0) }),
                    keyboard: .numberPad,
                    minus: { let v = Plan.step(row.reps, fallback: Double(hint?.reps ?? "") ?? 0, delta: -1); session.set(index, reps: v == "0" ? "" : v) },
                    plus: { session.set(index, reps: Plan.step(row.reps, fallback: Double(hint?.reps ?? "") ?? 0, delta: 1)) }
                )
                Image(systemName: logged ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(logged ? Color.green : Color.secondary)
                    .accessibilityLabel(logged ? "Set logged" : "Set not logged")
            }
            if !logged, let hint, index == firstOpen {
                Button {
                    session.set(index, weight: hint.weight, reps: hint.reps)
                } label: {
                    Label("\(hint.weight.isEmpty ? "" : hint.weight + " × ")\(hint.reps)", systemImage: "arrow.counterclockwise").font(.footnote)
                }
                .padding(.leading, 30)
            }
        }
        .padding(.vertical, 4)
    }

    private var firstOpen: Int { session.rows().firstIndex { !Plan.filled($0) } ?? 0 }
}

private struct StepperField: View {
    let placeholder: String
    let text: Binding<String>
    let keyboard: UIKeyboardType
    let minus: () -> Void
    let plus: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: minus) { Image(systemName: "minus").frame(width: 28, height: 36) }
                .buttonStyle(.bordered)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.center)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 56)
            Button(action: plus) { Image(systemName: "plus").frame(width: 28, height: 36) }
                .buttonStyle(.bordered)
        }
    }
}

private struct BottomBar: View {
    let session: LoggingSession
    @Binding var showList: Bool
    let close: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            RestBar()
            HStack {
                Button {
                    session.index -= 1
                } label: { Label("Previous", systemImage: "chevron.left") }
                .disabled(session.index == 0)

                Spacer()
                Button { showList = true } label: {
                    Text("\(session.index + 1) of \(session.day.exercises.count) ▾").font(.subheadline)
                }
                Spacer()

                if session.isLast {
                    Button("Finish") { session.finish(); close() }.buttonStyle(.borderedProminent)
                } else {
                    Button { session.index += 1 } label: { Label("Next", systemImage: "chevron.right").labelStyle(.titleAndIcon) }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

private struct ExerciseListSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: LoggingSession

    var body: some View {
        NavigationStack {
            List(Array(session.day.exercises.enumerated()), id: \.offset) { i, e in
                Button {
                    session.index = i
                    dismiss()
                } label: {
                    HStack {
                        Text(Plan.effectiveName(session.log, e.name)).fontWeight(i == session.index ? .bold : .regular)
                        Spacer()
                        let done = session.exerciseProgress(e)
                        Text("\(done >= e.sets ? "✓ " : "")\(done) / \(e.sets) sets").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}

/// The rest countdown, pinned above the Previous / Next bar while it runs.
struct RestBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        if let deadline = timer.deadline {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let left = max(0, deadline.timeIntervalSince(context.date))
                HStack {
                    Text(left > 0 ? Plan.clock(left) : "Go!").font(.title2.monospacedDigit().bold())
                    Spacer()
                    if left > 0 {
                        Button("+15") { timer.add(15) }.buttonStyle(.bordered)
                        Button("Skip") { timer.stop() }.buttonStyle(.bordered)
                    } else {
                        Button("Dismiss") { timer.stop() }.buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            }
            .task(id: deadline) {
                let wait = deadline.timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if !Task.isCancelled { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            }
        }
    }
}

#Preview {
    LoggingView(day: SampleData.plan[0])
        .environment(AppModel.sample())
        .environment(RestTimer())
}

/// Swap the open exercise for today only, or for good in the plan.
private struct SwapSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let session: LoggingSession
    @State private var query = ""

    private var suggestions: [String] {
        let current = session.exercise
        let fromPlan = model.plan.flatMap { $0.exercises.map(\.name) }
        let pool = Array(Set((current.alternatives ?? []) + fromPlan)).sorted()
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return pool.filter { $0 != current.name && (q.isEmpty || $0.lowercased().contains(q)) }.prefix(10).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Replace \(session.exercise.name) with") {
                    TextField("Exercise name", text: $query).textInputAutocapitalization(.sentences)
                }
                if !suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(suggestions, id: \.self) { name in
                            Button(name) { query = name }.foregroundStyle(.primary)
                        }
                    }
                }
                Section {
                    Button("Today only") { session.swapToday(to: query); dismiss() }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                    if !session.isCopiedTemplate {
                        Button("Always (change the plan)") {
                            if let renamed = session.swapAlways(to: query) {
                                model.savePlan(model.plan.map { $0.day == renamed.day ? renamed : $0 })
                                dismiss()
                            }
                        }
                        .disabled(query.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    if session.isSwapped { Button("Undo today's swap", role: .destructive) { session.swapToday(to: ""); dismiss() } }
                } footer: {
                    Text("Today only leaves your plan alone. Always renames it in the plan; history stays under the old name.")
                }
            }
            .navigationTitle("Swap exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
    }
}
