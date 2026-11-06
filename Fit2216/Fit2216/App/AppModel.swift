import SwiftUI
import Observation
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
    var weights: [WeightEntry] = []
    var profile = Profile()
    var phase: Phase = .idle

    @ObservationIgnored private let service = FirestoreService()
    var firestore: FirestoreService { service }
    private(set) var uid: String?

    /// Bumped at midnight and when the app comes back, so screens that show "today" move on to the new day.
    private(set) var tick = 0
    @ObservationIgnored private var lastLoaded: Date?

    var now: Date { _ = tick; return Date() }

    func dayChanged() { tick += 1 }

    /// True once there is data to work from: logging and food entry wait for this so nothing is overwritten by an empty copy.
    var canLog: Bool {
        switch phase { case .ready, .stale: return true; default: return false }
    }

    private func apply(_ loaded: FirestoreService.Loaded) {
        plan = loaded.doc.plan
        library = loaded.doc.library
        profile = loaded.doc.profile
        logs = loaded.logs
        weights = loaded.weights
    }

    /// Shows what this phone already holds straight away (it works offline and with a weak signal), then refreshes from the server.
    func load(uid: String) async {
        self.uid = uid
        let hadData = !plan.isEmpty || !logs.isEmpty
        if !hadData {
            phase = .loading
            if let cached = try? await service.loadAll(uid: uid, source: .cache), !cached.doc.plan.isEmpty || !cached.logs.isEmpty {
                apply(cached)
                phase = .stale("Showing what is saved on this phone. Updating…")
            }
        }
        do {
            apply(try await service.loadAll(uid: uid, source: .default))
            lastLoaded = Date()
            phase = .ready
        } catch {
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
        if let uid { service.saveWeight(uid: uid, entry: entry) }
        // The newest weigh-in keeps the body details, and so the targets, current. Only those fields are written.
        if entry.date >= (weights.first?.date ?? "") {
            updateProfile(keys: ["profile.weightKg", "profile.proteinMin", "profile.proteinMax"]) { $0.weightKg = entry.kg }
        }
    }

    func deleteWeight(date: String) {
        weights.removeAll { $0.date == date }
        if let uid { service.deleteWeight(uid: uid, date: date) }
    }

    func deleteLog(_ log: WorkoutLog) {
        let id = Logging.documentID(log)
        logs.removeAll { Logging.documentID($0) == id }
        if let uid { service.deleteLog(uid: uid, log: log) }
    }

    func savePlan(_ newPlan: [TemplateDay]) {
        plan = newPlan
        // The exercise library only grows: names from earlier plans stay available for autocomplete.
        var names = Set(library)
        for d in newPlan { for e in d.exercises where !e.name.trimmingCharacters(in: .whitespaces).isEmpty { names.insert(e.name) } }
        library = names.sorted()
        if let uid { service.savePlan(uid: uid, plan: newPlan, library: library) }
    }

    /// Changes some profile fields and writes only those (plus the protein range, which follows the targets).
    func updateProfile(keys: Set<String>, _ change: (inout Profile) -> Void) {
        var p = profile
        change(&p)
        profile = p
        if let uid { service.updateProfile(uid: uid, fields: p.updateFields(targets: targets, only: keys)) }
    }

    /// Saves every field of the body-and-targets form, and keeps the protein range in step with the new targets.
    func saveProfile(_ p: Profile) {
        profile = p
        if let uid { service.updateProfile(uid: uid, fields: p.updateFields(targets: targets)) }
    }

    /// Re-reads everything after a restore or an import.
    func reload() async {
        guard let uid else { return }
        await load(uid: uid)
    }

    /// Shows a changed workout at once and writes it to Firestore.
    func save(_ log: WorkoutLog) {
        let id = Logging.documentID(log)
        if let i = logs.firstIndex(where: { Logging.documentID($0) == id }) { logs[i] = log } else { logs.insert(log, at: 0) }
        if let uid { service.saveLog(uid: uid, log: log) }
    }

    func reset() {
        uid = nil
        plan = []; library = []; logs = []; weights = []; profile = Profile(); phase = .idle; lastLoaded = nil
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
