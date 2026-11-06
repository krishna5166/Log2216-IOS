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
        case failed(String)
    }

    var plan: [TemplateDay] = []
    var logs: [WorkoutLog] = []
    var weights: [WeightEntry] = []
    var profile = Profile()
    var phase: Phase = .idle

    @ObservationIgnored private let service = FirestoreService()
    var firestore: FirestoreService { service }
    private(set) var uid: String?

    var now: Date { Date() }

    func load(uid: String) async {
        self.uid = uid
        phase = .loading
        do {
            let doc = try await service.loadUserDoc(uid: uid)
            plan = doc.plan
            profile = doc.profile
            logs = try await service.loadLogs(uid: uid)
            weights = (try? await service.loadWeights(uid: uid)) ?? [] // a missing weigh-in list must not block the rest
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
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
        // The newest weigh-in keeps the body details, and so the targets, current.
        if entry.date >= (weights.first?.date ?? "") {
            var p = profile
            p.weightKg = entry.kg
            saveProfile(p)
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
        var library = Set<String>()
        for d in newPlan { for e in d.exercises where !e.name.trimmingCharacters(in: .whitespaces).isEmpty { library.insert(e.name) } }
        if let uid { service.savePlan(uid: uid, plan: newPlan, library: library.sorted()) }
    }

    /// Saves the profile and keeps the protein range in step with the new targets.
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
        plan = []; logs = []; weights = []; profile = Profile(); phase = .idle
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
