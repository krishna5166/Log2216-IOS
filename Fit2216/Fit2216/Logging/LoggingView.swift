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
                } else if day.exercises.isEmpty {
                    ContentUnavailableView("Nothing to log", systemImage: "bed.double", description: Text("This day has no exercises. Add some in Edit plan."))
                } else if case .failed(let message) = model.phase {
                    ContentUnavailableView("Could not load your data", systemImage: "exclamationmark.triangle", description: Text(message))
                } else {
                    ProgressView("Loading…")
                }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(day.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                        .accessibilityLabel("Back to Home")
                }
            }
        }
        .task(id: model.canLog) { await start() }
        .preferredColorScheme(.dark)
        .tint(Theme.lime)
    }

    /// The workout as it is on the server right now (waiting at most a couple of seconds), so one started on another device is continued, not overwritten.
    private func freshLog(id: String) async -> WorkoutLog? {
        guard let uid = model.uid else { return nil }
        let service = model.firestore
        return await withTaskGroup(of: WorkoutLog?.self) { group in
            group.addTask { (try? await service.loadLog(uid: uid, id: id)) ?? nil }
            group.addTask { try? await Task.sleep(for: .seconds(2.5)); return nil }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func start() async {
        // Wait until the plan and workouts have loaded: starting from an empty copy would overwrite today's real workout.
        guard session == nil, model.canLog, !day.exercises.isEmpty else { return }
        let date = Dates.localDate(model.now)
        var existing = model.logs
        let id = "\(date)_\(day.day)"
        if let fresh = await freshLog(id: id) {
            existing.removeAll { Logging.documentID($0) == id }
            existing.append(fresh)
        }
        guard session == nil else { return }
        let log = Logging.open(day: day, date: date, existing: existing, gymUnit: model.profile.gymUnit)
        var followed = Logging.day(for: log, plan: model.plan, fallback: day)
        if followed.exercises.isEmpty { followed = day } // a copied day with no exercises must not leave the screen with nothing to open
        session = LoggingSession(day: followed, log: log, history: model.recordLogs, timer: timer) { model.save($0) }
        RestTimer.requestPermission()
    }
}

private struct ExerciseScreen: View {
    @Environment(\.dismiss) private var dismiss
    let session: LoggingSession
    @State private var showList = false
    @State private var showSwap = false
    @State private var confirmSkip = false
    @State private var selected: Int?
    @State private var weight = ""
    @State private var reps = ""
    @AppStorage("autoAdvance") private var autoAdvance = true
    @State private var showComplete = false
    @State private var finalResult: WorkoutResult?
    @State private var finalElapsed: TimeInterval = 0

    private var rows: [SetLog] { session.rows() }
    private var firstOpen: Int? { rows.firstIndex { !Plan.filled($0) } }
    /// The set on screen: the one you tapped, else the first one not logged yet (nil when all are done).
    private var current: Int? {
        if let selected, selected < rows.count { return selected }
        return firstOpen
    }
    private var draftKey: String {
        guard let i = current, i < rows.count else { return "\(session.index)|none" }
        return "\(session.index)|\(session.shownName)|\(i)|\(rows[i].weight)/\(rows[i].reps)"
    }
    private var canLog: Bool { (Int(reps) ?? 0) > 0 }

    var body: some View {
        let e = session.exercise

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(e)
                setStack
                trend
                extras
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .keyboardDoneButton()
        .safeAreaInset(edge: .bottom) { BottomBar(session: session, showList: $showList, finish: finishWorkout) }
        .fullScreenCover(isPresented: $showComplete) {
            WorkoutCompleteView(result: finalResult ?? session.result(), elapsed: finalElapsed, unit: session.unit) { dismiss() }
        }
        .sheet(isPresented: $showList) { ExerciseListSheet(session: session) }
        .sheet(isPresented: $showSwap) { SwapSheet(session: session) }
        .onChange(of: draftKey, initial: true) { loadDrafts() }
        .onChange(of: session.index) { selected = nil }
        .onChange(of: weight) { _, v in
            let n = Logging.numeric(v, decimal: true)
            if n != v { weight = n }
        }
        .onChange(of: reps) { _, v in
            let n = Logging.numeric(v, decimal: false)
            if n != v { reps = n }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showSwap = true } label: { Label("Swap exercise", systemImage: "arrow.triangle.2.circlepath") }
                    Button { finishWorkout() } label: { Label("Finish workout", systemImage: "checkmark.circle") }
                        .disabled(!session.canFinish)
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

    // MARK: Pieces

    private func header(_ e: TemplateExercise) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("EXERCISE \(session.index + 1) OF \(session.day.exercises.count)")
                    .font(.caption.weight(.bold)).foregroundStyle(Theme.lime)
                Text(session.shownName)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(2).minimumScaleFactor(0.7)
                Text("\(e.sets) × \(e.reps) reps" + (e.optional == true ? " · optional" : ""))
                    .font(.subheadline).foregroundStyle(.secondary)
                if session.isSwapped {
                    Text("Swapped today from \(e.name)").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            elapsed
        }
    }

    /// Time since the workout screen opened, in yellow like the Fitness stopwatch.
    private var elapsed: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(Plan.clock(max(0, context.date.timeIntervalSince(session.startedAt))))
                .font(.system(size: 30, weight: .medium, design: .rounded).monospacedDigit())
                .foregroundStyle(.yellow)
                .accessibilityLabel("Workout time \(Plan.clock(max(0, context.date.timeIntervalSince(session.startedAt))))")
        }
    }

    /// Every planned set, stacked. The set you are on is open with big numbers; the others are one line each.
    private var setStack: some View {
        VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if i == current { activeSet(i) } else { compactSet(i, row) }
            }
            if current == nil { allDone }
        }
    }

    private func numberCircle(_ i: Int, logged: Bool, isCurrent: Bool) -> some View {
        Text("\(i + 1)")
            .font(.headline.monospacedDigit())
            .frame(width: 40, height: 40)
            .foregroundStyle(logged ? Color.black : (isCurrent ? Theme.lime : Color.white))
            .background(Circle().fill(logged ? Theme.lime : Color.white.opacity(0.12)))
            .overlay(Circle().stroke(Theme.lime, lineWidth: isCurrent && !logged ? 2 : 0))
    }

    private func compactSet(_ i: Int, _ row: SetLog) -> some View {
        let logged = Plan.filled(row)
        let unit = session.unit.rawValue
        return Button {
            selected = i
            Haptics.light()
        } label: {
            HStack(spacing: 14) {
                numberCircle(i, logged: logged, isCurrent: false)
                if logged {
                    BigValue(value: row.weight.isEmpty ? "–" : row.weight, unit: row.weight.isEmpty ? "" : unit, color: .white, size: 26)
                    Text("× \(row.reps)").font(.system(size: 22, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
                } else {
                    Text("Not logged yet").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if logged { Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Theme.lime) }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(session.shownName) set \(i + 1) of \(rows.count), "
                            + (logged ? "logged \(row.weight.isEmpty ? "no weight" : row.weight + " " + unit) for \(row.reps)" : "not logged"))
        .accessibilityHint("Opens this set to edit")
    }

    private func activeSet(_ i: Int) -> some View {
        let logged = Plan.filled(rows[i])
        let hint = session.hint(for: i)
        let step = Logging.step(session.unit)

        return HStack(alignment: .top, spacing: 12) {
            numberCircle(i, logged: logged, isCurrent: true)
            VStack(alignment: .leading, spacing: 16) {
                bigMetric("Weight (\(session.unit.rawValue))", name: "weight", text: $weight, keyboard: .decimalPad,
                          minus: { weight = Plan.step(weight, fallback: Double(hint?.weight ?? "") ?? 0, delta: -step) },
                          plus: { weight = Plan.step(weight, fallback: Double(hint?.weight ?? "") ?? 0, delta: step) })

                bigMetric("Reps", name: "reps", text: $reps, keyboard: .numberPad,
                          minus: { let v = Plan.step(reps, fallback: Double(hint?.reps ?? "") ?? 0, delta: -1); reps = v == "0" ? "" : v },
                          plus: { reps = Plan.step(reps, fallback: Double(hint?.reps ?? "") ?? 0, delta: 1) })

                Button { logSet(i) } label: {
                    Text(logged ? "Update set" : "Log set").limeCapsule(height: 54, enabled: canLog)
                }
                .buttonStyle(.plain)
                .disabled(!canLog)
                .accessibilityLabel("\(logged ? "Update" : "Log") \(session.shownName) set \(i + 1)")

                if logged {
                    Button("Clear this set", role: .destructive) {
                        session.set(i, weight: "", reps: "")
                        selected = nil
                    }
                    .font(.footnote)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.lime.opacity(0.8), lineWidth: 1.5))
    }

    /// The lift's overall progress as a quiet sparkline, so you see whether today's weight keeps the trend going.
    private var trend: some View {
        let values = session.strength().weeks.map(\.score)
        return VStack(alignment: .leading, spacing: 8) {
            Text("YOUR TREND").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            if values.compactMap({ $0 }).count >= 2 {
                Sparkline(values: values).frame(height: 64)
            } else {
                Text("Log this lift over a few weeks to see your trend.").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func bigMetric(_ label: String, name: String, text: Binding<String>, keyboard: UIKeyboardType,
                           minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                TextField("0", text: text)
                    .accessibilityLabel(label)
                    .keyboardType(keyboard)
                    .font(.system(size: 52, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                Text(label).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            roundButton("minus", label: "Decrease \(name)", action: minus)
            roundButton("plus", label: "Increase \(name)", action: plus)
        }
    }

    private func roundButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.light()
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.bold))
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.white.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var allDone: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Theme.lime)
            Text("All sets done").font(.title2.bold())
            Text(session.isLast ? "Finish the workout below, or tap a set to change it." : "On to the next exercise, or tap a set to change it.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var extras: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let pb = session.personalBest {
                Label("New personal best: \(Units.tidy(pb.weight)) \(session.unit.rawValue) × \(Int(pb.reps)) (estimated max up \(Units.tidy(pb.gain)) \(session.unit.rawValue))", systemImage: "trophy.fill")
                    .font(.subheadline.bold()).foregroundStyle(.orange)
            }
            if let last = session.lastTime {
                Text("Last: \(Plan.formatSets(last.sets, unit: session.unit)) · \(Format.date(last.date))")
                    .font(.footnote).foregroundStyle(.secondary)
                if session.readyToIncrease {
                    Text("Top of the range, so we suggest +\(Units.tidy(Logging.step(session.unit))) \(session.unit.rawValue)")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !session.earlier.isEmpty {
                    DisclosureGroup("Earlier sessions") {
                        ForEach(session.earlier, id: \.date) { s in
                            HStack {
                                Text(Format.date(s.date)).foregroundStyle(.secondary)
                                Spacer()
                                Text(Plan.formatSets(s.sets, unit: session.unit))
                            }
                            .font(.footnote)
                        }
                    }
                    .font(.footnote)
                }
            }
        }
    }

    // MARK: Actions

    /// Fills the boxes for the set on screen: what is logged, else the suggestion, else the bottom of the rep range.
    private func loadDrafts() {
        guard let i = current, i < rows.count else { weight = ""; reps = ""; return }
        let row = rows[i]
        if Plan.filled(row) { weight = row.weight; reps = row.reps; return }
        let hint = session.hint(for: i)
        weight = row.weight.isEmpty ? (hint?.weight ?? "") : row.weight
        reps = row.reps.isEmpty ? (hint?.reps ?? String(session.exercise.reps.prefix { $0.isNumber })) : row.reps
    }

    private func logSet(_ i: Int) {
        guard canLog else { return }
        let wasLogged = Plan.filled(rows[i])
        let here = session.index
        session.set(i, weight: Logging.numeric(weight, decimal: true), reps: Logging.numeric(reps, decimal: false))
        selected = nil
        // Last set of this exercise just logged: move on after a beat (not when editing a set that was already logged).
        if autoAdvance, !wasLogged, session.loggedCount >= session.exercise.sets, !session.isLast {
            Task {
                try? await Task.sleep(for: .milliseconds(800))
                if session.index == here { session.index += 1 }
            }
        }
    }

    /// Saves the workout as finished and shows the summary; Done there closes the workout.
    private func finishWorkout() {
        guard session.canFinish else { return }
        finalElapsed = Date().timeIntervalSince(session.startedAt)
        session.finish()
        finalResult = session.result()
        showComplete = true
    }
}

private struct BottomBar: View {
    let session: LoggingSession
    @Binding var showList: Bool
    let finish: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            RestBar()
            HStack {
                Button { session.index -= 1 } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 52, height: 52)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                .disabled(session.index == 0)
                .opacity(session.index == 0 ? 0.3 : 1)
                .accessibilityLabel("Previous exercise")

                Spacer()
                Button { showList = true } label: {
                    HStack(spacing: 4) {
                        Text("\(session.index + 1) of \(session.day.exercises.count)").font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.up").font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                Spacer()

                if session.isLast {
                    Button { finish() } label: {
                        Text("Finish").font(.headline).frame(width: 110, height: 52)
                            .foregroundStyle(.black).background(Theme.lime, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!session.canFinish)
                    .opacity(session.canFinish ? 1 : 0.35)
                } else {
                    Button { session.index += 1 } label: {
                        HStack(spacing: 6) { Text("Next"); Image(systemName: "chevron.right") }
                            .font(.headline).frame(width: 110, height: 52)
                            .foregroundStyle(.black).background(Theme.lime, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black)
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

/// The rest countdown, pinned above the Previous / Next bar while it runs: a big yellow clock in a pill, like the stopwatch in Fitness.
struct RestBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        if let deadline = timer.deadline {
            TimelineView(.periodic(from: .now, by: 0.5)) { context in
                let left = max(0, deadline.timeIntervalSince(context.date))
                HStack(spacing: 10) {
                    Text(left > 0 ? Plan.clock(left) : "Go!")
                        .font(.system(size: 38, weight: .medium, design: .rounded).monospacedDigit())
                        .foregroundStyle(.yellow)
                        .padding(.leading, 8)
                    Spacer()
                    if left > 0 {
                        pill("+15") { timer.add(15) }
                        pill("Skip") { timer.stop() }
                    } else {
                        pill("Dismiss") { timer.stop() }
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color(white: 0.13), in: Capsule())
            }
            .task(id: deadline) {
                let wait = deadline.timeIntervalSinceNow
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                if !Task.isCancelled { Haptics.success() }
            }
        }
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).frame(height: 40)
                .background(Capsule().fill(Color.white.opacity(0.14)))
        }
        .buttonStyle(.plain)
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
