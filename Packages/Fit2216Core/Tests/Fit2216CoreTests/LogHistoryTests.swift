import XCTest
@testable import Fit2216Core

final class LogHistoryTests: XCTestCase {
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }
    private func log(_ date: String, _ sets: [String: [SetLog]]) -> WorkoutLog { WorkoutLog(date: date, dayName: "Legs", dayIndex: 1, sets: sets) }

    func testRecentWinsAndNothingIsDuplicated() {
        let archive = [log("2026-01-05", ["Squat": [s("100", "5")]]), log("2026-10-05", ["Squat": [s("80", "5")]])]
        let recent = [log("2026-10-05", ["Squat": [s("90", "5")]]), log("2026-10-12", ["Squat": [s("95", "5")]])]
        let all = LogHistory.merged(recent: recent, archive: archive)
        XCTAssertEqual(all.map(\.date), ["2026-10-12", "2026-10-05", "2026-01-05"])
        XCTAssertEqual(all[1].sets["Squat"]?.first?.weight, "90") // the recent copy replaced the archived one
    }

    func testWithoutAnArchiveItIsJustTheRecentWorkouts() {
        let recent = [log("2026-10-12", ["Squat": [s("95", "5")]])]
        XCTAssertEqual(LogHistory.merged(recent: recent, archive: []), recent)
    }

    func testAnOldRecordStopsALighterLiftBeingCalledANewBest() {
        let old = log("2025-01-05", ["Squat": [s("140", "5")]])           // far outside the recent window
        let recent = [log("2026-10-05", ["Squat": [s("100", "5")]])]
        let today = [s("105", "5")]
        // Judged on the recent window alone, 105 looks like a record; against the whole history it is not.
        let windowOnly = Insights.liftHistory(recent)["Squat"]
        XCTAssertNotNil(PersonalBests.best(history: windowOnly, sets: today, unit: .kg))
        let whole = Insights.liftHistory(LogHistory.merged(recent: recent, archive: [old]))["Squat"]
        XCTAssertNil(PersonalBests.best(history: whole, sets: today, unit: .kg))
    }
}
