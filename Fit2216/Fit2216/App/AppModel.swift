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

    var now: Date { Date() }

    func load(uid: String) async {
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

    func reset() {
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
