import XCTest
@testable import Fit2216Core

final class RobustnessTests: XCTestCase {
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }

    func testNumericInputIsCleanedLikeTheWebApp() {
        XCTAssertEqual(Logging.numeric("12a3", decimal: false), "123")
        XCTAssertEqual(Logging.numeric("1234567", decimal: false), "123456")
        XCTAssertEqual(Logging.numeric("22.5", decimal: true), "22.5")
        XCTAssertEqual(Logging.numeric("1.2.3", decimal: true), "1.23")
        XCTAssertEqual(Logging.numeric("22,5", decimal: true), "22.5")   // a keyboard that types a comma
        XCTAssertEqual(Logging.numeric("-5x", decimal: true), "5")
        XCTAssertEqual(Logging.numeric("", decimal: true), "")
    }

    func testAPlanWithOutOfRangeDaysAndSetsCannotBreakAScreen() throws {
        let plan = try decode(LossyPlan.self, #"[{"day":9,"name":"Bad","type":"strength","exercises":[]},{"day":-1,"name":"Bad2","type":"rest","exercises":[]},{"day":2,"name":"Pull","type":"strength","exercises":[{"name":"Row","sets":0,"reps":"8"},{"name":"Curl","sets":500,"reps":"8"}]}]"#)
        XCTAssertEqual(plan.days.map(\.day), [2])
        XCTAssertEqual(plan.days[0].exercises.map(\.sets), [1, 100])
        XCTAssertNil(try decode(WorkoutLog.self, #"{"date":"2026-10-28","dayName":"x","dayIndex":12}"#).dayIndex)
        XCTAssertEqual(try decode(WorkoutLog.self, #"{"date":"2026-10-28","dayName":"x","dayIndex":3}"#).dayIndex, 3)
    }

    func testAnEmptyWorkoutCannotBeFinished() {
        XCTAssertFalse(Logging.canFinish(WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 1)))
        XCTAssertTrue(Logging.canFinish(Logging.setting(WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 1), exercise: "Bench", index: 0, weight: "60", reps: "5")))
    }

    func testPersonalBestNeedsEarlierHistoryAndABetterEstimatedMax() {
        let history = [LiftPoint(date: "2026-10-01", e1rm: 100, weight: 90, reps: 3), LiftPoint(date: "2026-10-10", e1rm: 105, weight: 90, reps: 5)]
        XCTAssertNil(PersonalBests.best(history: nil, sets: [s("200", "5")], unit: .kg))                  // a first session is a start, not a record
        XCTAssertNil(PersonalBests.best(history: [], sets: [s("200", "5")], unit: .kg))
        XCTAssertNil(PersonalBests.best(history: history, sets: [s("90", "5")], unit: .kg))               // equals the best: not a record
        let pb = PersonalBests.best(history: history, sets: [s("80", "5"), s("100", "5")], unit: .kg)!
        XCTAssertEqual(pb.weight, 100, accuracy: 0.001); XCTAssertEqual(pb.reps, 5)
        XCTAssertEqual(pb.gain, 100 * (1 + 5.0 / 30) - 105, accuracy: 0.01)                                // the better of today's sets
        // sets typed in pounds are compared in kilograms and reported back in pounds
        let lb = PersonalBests.best(history: history, sets: [s("220", "5")], unit: .lb)!
        XCTAssertEqual(lb.weight, 220, accuracy: 0.001)
    }

    func testTodaysRecordsUseTheNameActuallyDone() {
        let lifts = ["Hack squats": [LiftPoint(date: "2026-10-01", e1rm: 100, weight: 80, reps: 5)]]
        let log = WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 1, sets: ["Squat": [s("100", "5")]], swaps: ["Squat": "Hack squats"])
        let records = PersonalBests.todaysRecords(log: log, lifts: lifts)
        XCTAssertEqual(records.map(\.name), ["Hack squats"])
    }

    func testTargetedProfileUpdatesOnlyTouchTheNamedFields() {
        let p = Profile(name: "Me", heightCm: 175, goal: .lose, sex: .male, age: 30, weightKg: 80)
        let targets = Nutrition.computeTargets(p, autoSessions: 3)
        let f = p.updateFields(targets: targets, only: ["profile.weightKg", "profile.proteinMin", "profile.proteinMax"])
        XCTAssertEqual(Set(f.keys), ["profile.weightKg", "profile.proteinMin", "profile.proteinMax"])
        XCTAssertEqual(p.updateFields(targets: nil, only: ["profile.gymUnit"]).count, 1)
    }
}
