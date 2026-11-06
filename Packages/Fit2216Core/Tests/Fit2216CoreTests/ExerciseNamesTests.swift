import XCTest
@testable import Fit2216Core

final class ExerciseNamesTests: XCTestCase {
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }
    private func log(_ date: String, _ sets: [String: [SetLog]], swaps: [String: String]? = nil) -> WorkoutLog {
        WorkoutLog(date: date, dayName: "Legs", dayIndex: 1, sets: sets, swaps: swaps)
    }

    func testCanonicalTidiesAndAppliesAliases() {
        XCTAssertEqual(ExerciseNames.canonical("  Bench   press "), "Bench press")
        XCTAssertEqual(ExerciseNames.canonical("Romanian Squat"), "Squat")
        XCTAssertEqual(Plan.effectiveName(log("2026-10-01", [:]), "Romanian squat"), "Squat")
    }

    func testKeyFoldsCasePunctuationAndPlurals() {
        XCTAssertEqual(ExerciseNames.key("Pull-ups"), ExerciseNames.key("pull ups"))
        XCTAssertEqual(ExerciseNames.key("Squats"), ExerciseNames.key("squat"))
        XCTAssertNotEqual(ExerciseNames.key("Bench press"), ExerciseNames.key("Incline press"))
        XCTAssertEqual(ExerciseNames.key("Leg press"), "leg press") // "press" keeps its double s
    }

    func testHistoryStitchesAcrossARename() {
        let logs = [log("2026-10-06", ["Romanian squat": [s("100", "5")]]), log("2026-10-13", ["Squat": [s("105", "5")]])]
        XCTAssertEqual(Insights.liftHistory(logs)["Squat"]?.count, 2)
        XCTAssertNil(Insights.liftHistory(logs)["Romanian squat"])
    }

    func testDriftFindsSpellingsAndPicksThePlanName() {
        let plan = [TemplateDay(day: 1, name: "Legs", type: .strength, exercises: [TemplateExercise(name: "Bench press", sets: 3, reps: "8")])]
        let logs = [
            log("2026-10-01", ["bench press": [s("60", "8")]]), log("2026-10-08", ["bench press": [s("60", "8")]]),
            log("2026-10-15", ["Bench press": [s("62", "8")]]), log("2026-10-22", ["Row": [s("50", "10")]]),
        ]
        let groups = ExerciseNames.drift(plan: plan, logs: logs)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].target, "Bench press")
        XCTAssertEqual(groups[0].names.map(\.name), ["bench press", "Bench press"]) // most used first
        XCTAssertTrue(ExerciseNames.drift(plan: plan, logs: [log("2026-10-01", ["Bench press": [s("60", "8")]])]).isEmpty)
    }

    func testRenameRewritesKeysAndSwapsAndSkipsLogsUsingBoth() {
        let group = DriftGroup(names: [DriftName(name: "Squat", count: 3), DriftName(name: "squats", count: 1)], target: "Squat")
        let plain = log("2026-10-01", ["squats": [s("100", "5")]])
        let swapped = log("2026-10-02", ["Press": [s("40", "8")]], swaps: ["Press": "squats"])
        let both = log("2026-10-03", ["Squat": [s("100", "5")], "squats": [s("90", "8")]])
        let result = ExerciseNames.rename(logs: [plain, swapped, both], groups: [group])
        XCTAssertEqual(result.changed.count, 2)
        XCTAssertEqual(result.skipped, 1)
        XCTAssertEqual(result.changed[0].sets["Squat"]?.count, 1)
        XCTAssertNil(result.changed[0].sets["squats"])
        XCTAssertEqual(result.changed[1].swaps?["Press"], "Squat")
        XCTAssertEqual(result.changed[1].sets["Press"]?.count, 1)
    }

    func testShareRoundTripsAndRejectsForeignText() {
        let day = TemplateDay(day: 1, name: "Legs", type: .strength, exercises: [TemplateExercise(name: "Bench press", sets: 3, reps: "8-10", restSec: 90)])
        let l = log("2026-10-01", ["Bench press": [s("60", "8")]], swaps: ["Bench press": "Dumbbell press"])
        let text = WorkoutCopy.export(log: l, plan: [day])
        let back = text.flatMap(WorkoutCopy.parse)
        XCTAssertEqual(back?.exercises.first?.name, "Dumbbell press")
        XCTAssertEqual(back?.exercises.first?.restSec, 90)
        XCTAssertNil(WorkoutCopy.parse("hello"))
        XCTAssertNil(WorkoutCopy.parse(#"{"app":"other","kind":"workout","v":1,"day":{}}"#))
        XCTAssertNotNil(WorkoutCopy.parse("Here you go:\n" + (text ?? "") + "\nenjoy"))
    }

    func testSourceDayRebuildsFromLoggedSetsWhenThePlanChanged() {
        let l = log("2026-10-01", ["Old lift": [s("50", "8"), s("50", "8"), s("", "")]])
        let rebuilt = WorkoutCopy.sourceDay(for: l, plan: [])
        XCTAssertEqual(rebuilt?.exercises.first?.sets, 2)
        XCTAssertNil(WorkoutCopy.sourceDay(for: log("2026-10-01", [:]), plan: []))
    }
}
