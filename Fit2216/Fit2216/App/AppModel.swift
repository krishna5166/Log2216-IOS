import SwiftUI
import Observation
import FirebaseFirestore
import Fit2216Core

/// What the screens read: the signed-in person's plan, recent workouts and profile.
@Observable
final class AppModel {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case stale(String)   // working from what this phone holds because the server could not be reached
        case failed(String)
    }

    var plan: [TemplateDay] = []
    var library: [String] = []
    var logs: [WorkoutLog] = []
    /// Every workout ever logged, read once and then from this phone's own copy (not refetched each launch). Empty until it has loaded.
    /// Used only to judge records against the whole history; `logs` stays the recent, always-fresh window the screens use.
    private(set) var archive: [WorkoutLog] = []
    var weights: [WeightEntry] = []
    var profile = Profile()
    var phase: Phase = .idle
    /// The feedback loop's newest plan proposal, shown with Yes / No until answered, and whether a workout screen is open (nothing is offered then).
    var planProposal: PlanProposal?
    var workoutOpen = false
    @ObservationIgnored var flushingFeedback = false
    /// Changes saved on this phone that the cloud has not confirmed yet (waiting for a connection), and the last reason one was refused.
    private(set) var unsent = 0
    private(set) var writeProblem: String?
    /// True once a change has been waiting more than a few seconds, so the notice does not flicker on every normal save.
    private(set) var slowSync = false
    @ObservationIgnored private var slowTimer: Task<Void, Never>?

    @ObservationIgnored private let service = FirestoreService()
    var firestore: FirestoreService { service }

    /// Runs a write and keeps count of the ones the cloud has not confirmed, so the screen can say "saved on this phone, will sync".
    func tracked(_ write: (@escaping (Error?) -> Void) -> Void) {
        unsent += 1
        if unsent == 1 {
            slowTimer = Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled, let self, self.unsent > 0 { self.slowSync = true }
            }
        }
        write { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.unsent = max(0, self.unsent - 1)
                if let error { self.writeProblem = error.localizedDescription } else if self.unsent == 0 { self.writeProblem = nil }
                if self.unsent == 0 { self.slowTimer?.cancel(); self.slowSync = false }
            }
        }
    }

    func dismissWriteProblem() { writeProblem = nil }
    private(set) var uid: String?

    /// Bumped at midnight and when the app comes back, so screens that show "today" move on to the new day.
    private(set) var tick = 0
    @ObservationIgnored private var lastLoaded: Date?

    var now: Date { _ = tick; return Date() }

    func dayChanged() { tick += 1 }

    /// Recent workouts plus the all-time archive (recent copies win): what personal bests and records are judged against.
    var recordLogs: [WorkoutLog] { LogHistory.merged(recent: logs, archive: archive) }

    /// Reads the whole history in the background. The first time (and every two weeks) it asks the server; otherwise it uses the copy this
    /// phone already holds, so there is no full download on every launch. Failure is harmless: records then use the recent window.
    private func loadArchive(uid: String, generation mine: Int) async {
        let key = "fit2216.archive.\(uid)"
        let last = UserDefaults.standard.object(forKey: key) as? Date
        let stale = last.map { Date().timeIntervalSince($0) > 14 * 24 * 3600 } ?? true
        var all: [WorkoutLog]?
        if stale, let fresh = try? await service.loadAllLogs(uid: uid, source: .server) {
            all = fresh
            UserDefaults.standard.set(Date(), forKey: key)
        } else if let cached = try? await service.loadAllLogs(uid: uid, source: .cache) {
            all = cached
        }
        guard let all, mine == generation, self.uid == uid else { return }
        archive = all
    }

    /// True once there is data to work from: logging and food entry wait for this so nothing is overwritten by an empty copy.
    var canLog: Bool {
        switch phase { case .ready, .stale: return true; default: return false }
    }

    private func apply(_ loaded: FirestoreService.Loaded) {
        plan = loaded.doc.plan
        // Half-typed leftovers ("B", "Ba", "Barb") from older versions are removed once and the tidy list is saved back.
        library = ExerciseLibrary.cleaned(loaded.doc.library, keeping: loaded.doc.plan.flatMap { $0.exercises.map(\.name) })
        if library != loaded.doc.library.sorted(), let uid, !loaded.doc.library.isEmpty {
            tracked { done in service.saveLibrary(uid: uid, library: library, completion: done) }
        }
        profile = loaded.doc.profile
        logs = loaded.logs
        weights = loaded.weights
    }

    /// Bumped on every load and every sign-out. A load that finishes after a newer one started (or after sign-out) is thrown away,
    /// so a slow answer for one account can never land in another account's screens.
    @ObservationIgnored private var generation = 0

    /// Shows what this phone already holds straight away (it works offline and with a weak signal), then refreshes from the server.
    func load(uid: String) async {
        if self.uid != uid { clearData() } // never show or edit another account's data
        generation += 1
        let mine = generation
        self.uid = uid
        let hadData = !plan.isEmpty || !logs.isEmpty
        if !hadData {
            phase = .loading
            if let cached = try? await service.loadAll(uid: uid, source: .cache), mine == generation, !cached.doc.plan.isEmpty || !cached.logs.isEmpty {
                apply(cached)
                phase = .stale("Showing what is saved on this phone. Updating…")
            }
        }
        do {
            let fresh = try await service.loadAll(uid: uid, source: .default)
            guard mine == generation else { return }
            apply(fresh)
            lastLoaded = Date()
            phase = .ready
            Task { await loadArchive(uid: uid, generation: mine) }
        } catch {
            guard mine == generation else { return }
            phase = (plan.isEmpty && logs.isEmpty) ? .failed(error.localizedDescription) : .stale("Offline: showing what is saved on this phone.")
        }
    }

    /// When the app comes back after a while, read again so changes from another device show up.
    func refreshIfNeeded() async {
        guard let uid, phase != .loading, Date().timeIntervalSince(lastLoaded ?? .distantPast) > 10 * 60 else { return }
        await load(uid: uid)
    }

    /// Today's calorie and macro targets from your body details and recent training, or nil until those are filled in.
    var targets: Targets? {
        Nutrition.computeTargets(profile, autoSessions: Nutrition.avgSessions(plan: plan, logs: logs, now))
    }

    func saveWeight(_ entry: WeightEntry) {
        weights.removeAll { $0.date == entry.date }
        weights.append(entry)
        weights.sort { $0.date > $1.date }
        if let uid { tracked { done in service.saveWeight(uid: uid, entry: entry, completion: done) } }
        // The newest weigh-in keeps the body details, and so the targets, current. Only those fields are written.
        if entry.date >= (weights.first?.date ?? "") {
            updateProfile(keys: ["profile.weightKg", "profile.proteinMin", "profile.proteinMax"]) { $0.weightKg = entry.kg }
        }
    }

    func deleteWeight(date: String) {
        weights.removeAll { $0.date == date }
        if let uid { tracked { done in service.deleteWeight(uid: uid, date: date, completion: done) } }
    }

    func deleteLog(_ log: WorkoutLog) {
        let id = Logging.documentID(log)
        logs.removeAll { Logging.documentID($0) == id }
        archive.removeAll { Logging.documentID($0) == id }
        if let uid { tracked { done in service.deleteLog(uid: uid, log: log, completion: done) } }
    }

    func savePlan(_ newPlan: [TemplateDay]) {
        plan = newPlan
        // The exercise library only grows: names from earlier plans stay available for autocomplete.
        var names = Set(library)
        for d in newPlan { for e in d.exercises where !e.name.trimmingCharacters(in: .whitespaces).isEmpty { names.insert(e.name) } }
        library = names.sorted()
        if let uid { tracked { done in service.savePlan(uid: uid, plan: newPlan, library: library, completion: done) } }
    }

    /// Changes some profile fields and writes only those (plus the protein range, which follows the targets).
    func updateProfile(keys: Set<String>, _ change: (inout Profile) -> Void) {
        var p = profile
        change(&p)
        profile = p
        if let uid { tracked { done in service.updateProfile(uid: uid, fields: p.updateFields(targets: targets, only: keys), completion: done) } }
    }

    /// Saves every field of the body-and-targets form, and keeps the protein range in step with the new targets.
    func saveProfile(_ p: Profile) {
        profile = p
        if let uid { tracked { done in service.updateProfile(uid: uid, fields: p.updateFields(targets: targets), completion: done) } }
    }

    /// Re-reads everything after a restore or an import.
    func reload() async {
        guard let uid else { return }
        await load(uid: uid)
    }

    /// Shows a changed workout at once and writes it to Firestore.
    func save(_ saved: WorkoutLog) {
        var log = saved
        let startsFeedback = prepareFeedback(&log)
        let id = Logging.documentID(log)
        if let i = logs.firstIndex(where: { Logging.documentID($0) == id }) { logs[i] = log } else { logs.insert(log, at: 0) }
        if let uid { tracked { done in service.saveLog(uid: uid, log: log, completion: done) } }
        if startsFeedback { queueFeedback(log) }
    }

    private func clearData() {
        plan = []; library = []; logs = []; archive = []; weights = []; profile = Profile(); phase = .idle; lastLoaded = nil
        planProposal = nil; workoutOpen = false
        unsent = 0; writeProblem = nil; slowSync = false; slowTimer?.cancel()
    }

    func reset() {
        generation += 1 // answers still on their way belong to the account that just left
        uid = nil
        clearData()
    }

    /// Sample data for previews.
    static func sample() -> AppModel {
        let m = AppModel()
        m.plan = SampleData.plan
        m.logs = SampleData.logsThisWeek(plan: SampleData.plan)
        m.weights = SampleData.weights()
        m.profile = Profile(name: "Mohan", units: .imperial, heightCm: 175, targetWeightKg: 72)
        m.phase = .ready
        return m
    }
}
