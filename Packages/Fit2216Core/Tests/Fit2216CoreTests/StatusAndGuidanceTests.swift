import XCTest
@testable import Fit2216Core

final class StatusAndGuidanceTests: XCTestCase {
    func testNothingWrongMeansNoNotice() {
        XCTAssertNil(Status.notice(loadFailed: nil, offline: nil, writeProblem: nil, unsent: 0, slowSync: false))
        XCTAssertNil(Status.notice(loadFailed: nil, offline: nil, writeProblem: nil, unsent: 2, slowSync: false)) // quick saves stay quiet
    }

    func testOnlyTheMostImportantNoticeIsShownAndWaitingChangesAreFolded() {
        let all = Status.notice(loadFailed: "No data", offline: "Offline", writeProblem: "denied", unsent: 3, slowSync: true)
        XCTAssertEqual(all?.kind, .problem); XCTAssertEqual(all?.message, "No data"); XCTAssertEqual(all?.action, .retry)

        let refused = Status.notice(loadFailed: nil, offline: "Offline", writeProblem: "denied", unsent: 1, slowSync: true)
        XCTAssertEqual(refused?.message, "A change could not be saved to the cloud: denied. 1 change is waiting to sync.")
        XCTAssertEqual(refused?.action, .dismiss)

        let offline = Status.notice(loadFailed: nil, offline: "Offline: showing what is saved on this phone.", writeProblem: nil, unsent: 2, slowSync: true)
        XCTAssertEqual(offline?.kind, .offline)
        XCTAssertEqual(offline?.message, "Offline: showing what is saved on this phone. 2 changes are waiting to sync.")

        let syncing = Status.notice(loadFailed: nil, offline: nil, writeProblem: nil, unsent: 1, slowSync: true)
        XCTAssertEqual(syncing, StatusNotice(kind: .syncing, message: "1 change saved on this phone, syncing…", action: .none))
    }

    private func session(_ state: TodaySession.State, planned: Int = 12, logged: Int = 0, isToday: Bool = true) -> TodaySession {
        let day = TemplateDay(day: 1, name: "Push", type: .strength, exercises: [
            TemplateExercise(name: "Bench", sets: 6, reps: "8"), TemplateExercise(name: "Fly", sets: 6, reps: "12")])
        return TodaySession(day: day, state: state, muscles: [], plannedSets: planned, loggedSets: logged, isToday: isToday)
    }

    func testGuidanceForEachState() {
        XCTAssertEqual(Summary.guidance(session(.notStarted)), Guidance(headline: "Ready when you are", detail: "12 sets across 2 exercises."))
        XCTAssertEqual(Summary.guidance(session(.inProgress, logged: 5)), Guidance(headline: "Keep going", detail: "7 sets left in Push."))
        XCTAssertEqual(Summary.guidance(session(.inProgress, logged: 11)).detail, "1 set left in Push.")
        XCTAssertEqual(Summary.guidance(session(.finished, logged: 12), nextName: "Pull · Wed").detail, "12 sets logged. Next: Pull · Wed.")
        XCTAssertEqual(Summary.guidance(session(.rest)).headline, "Rest day")
        XCTAssertEqual(Summary.guidance(session(.rest), nextName: "Legs").detail, "Recovery is part of the plan. Next: Legs.")
        XCTAssertEqual(Summary.guidance(session(.skipped)).headline, "Skipped today")
        XCTAssertEqual(Summary.guidance(session(.notStarted, isToday: false)), Guidance(headline: "Next up", detail: "Push, 12 sets."))
    }
}
