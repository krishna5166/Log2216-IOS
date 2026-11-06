import SwiftUI
import Observation
import Fit2216Core

/// What the screens read. For now it holds sample data; the Firestore-backed store replaces it later without changing the screens.
@Observable
final class AppModel {
    var plan: [TemplateDay]
    var logs: [WorkoutLog]

    init(plan: [TemplateDay] = SampleData.plan, logs: [WorkoutLog] = SampleData.logsThisWeek(plan: SampleData.plan)) {
        self.plan = plan
        self.logs = logs
    }

    var now: Date { Date() }
}
