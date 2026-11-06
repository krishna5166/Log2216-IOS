import XCTest
@testable import Fit2216Core

final class LoggingTests: XCTestCase {
    private let bench = TemplateExercise(name: "Bench", sets: 3, reps: "4–6")
    private let row = TemplateExercise(name: "Row", sets: 2, reps: "8")
    private var day: TemplateDay { TemplateDay(day: 1, name: "Push", exercises: [bench, row]) }
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }

    func testDocumentIDMatchesTheWebApp() {
        XCTAssertEqual(Logging.documentID(WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 3)), "2026-10-28_3")
        XCTAssertEqual(Logging.documentID(WorkoutLog(date: "2026-10-28", dayName: "x")), "2026-10-28")
    }

    func testOpenReusesTheSavedLogAndTakesTheGymUnitOnlyWhileEmpty() {
        let saved = WorkoutLog(date: "2026-10-28", dayName: "Push", dayIndex: 1, unit: .kg, sets: [:])
        XCTAssertEqual(Logging.open(day: day, date: "2026-10-28", existing: [saved], gymUnit: .lb).unit, .lb) // nothing typed: follows the gym unit
        let typed = WorkoutLog(date: "2026-10-28", dayName: "Push", dayIndex: 1, unit: .kg, sets: ["Bench": [s("60", "5")]])
        XCTAssertEqual(Logging.open(day: day, date: "2026-10-28", existing: [typed], gymUnit: .lb).unit, .kg) // has sets: keeps its unit
        let fresh = Logging.open(day: day, date: "2026-10-29", existing: [typed], gymUnit: .lb)
        XCTAssertEqual(fresh.dayIndex, 1); XCTAssertEqual(fresh.unit, .lb); XCTAssertEqual(fresh.sets, [:]); XCTAssertEqual(fresh.dayName, "Push")
    }

    func testLoggingSetThreeFirstLeavesNoHole() {
        let log = Logging.setting(WorkoutLog(date: "2026-10-28", dayName: "Push", dayIndex: 1), exercise: "Bench", index: 2, weight: "100", reps: "5")
        XCTAssertEqual(log.sets["Bench"], [SetLog(), SetLog(), s("100", "5")])
        let more = Logging.setting(log, exercise: "Bench", index: 0, reps: "6")
        XCTAssertEqual(more.sets["Bench"]?[0], SetLog(weight: "", reps: "6")) // reps only: weight untouched
        XCTAssertEqual(Logging.setsLogged(more, exercise: "Bench"), 2)
        let cleared = Logging.setting(more, exercise: "Bench", index: 0, reps: "")
        XCTAssertEqual(Logging.setsLogged(cleared, exercise: "Bench"), 1) // emptying the reps un-logs the set
    }

    func testFirstOpenIndexAndFinishAndSkip() {
        var log = WorkoutLog(date: "2026-10-28", dayName: "Push", dayIndex: 1)
        XCTAssertEqual(Logging.firstOpenIndex(day: day, log: log), 0)
        for i in 0..<3 { log = Logging.setting(log, exercise: "Bench", index: i, weight: "60", reps: "5") }
        XCTAssertEqual(Logging.firstOpenIndex(day: day, log: log), 1)
        for i in 0..<2 { log = Logging.setting(log, exercise: "Row", index: i, weight: "50", reps: "8") }
        XCTAssertEqual(Logging.firstOpenIndex(day: day, log: log), 0) // all done: open on the first
        XCTAssertEqual(Logging.finished(log).done, true)
        let skipped = Logging.skipped(Logging.finished(log))
        XCTAssertEqual(skipped.skipped, true); XCTAssertEqual(skipped.done, false)
    }

    func testSuggestionUsesThePreviousSetThenLastTimeWithAStepWhenReady() {
        let history = [WorkoutLog(date: "2026-10-21", dayName: "Push", dayIndex: 1, unit: .lb, sets: ["Bench": [s("100", "6"), s("100", "6"), s("100", "6")]])]
        let today = WorkoutLog(date: "2026-10-28", dayName: "Push", dayIndex: 1, unit: .lb)
        // every set last time hit the top of 4–6, so the first set suggests +5 lb
        XCTAssertEqual(Logging.suggestion(exercise: bench, shownName: "Bench", index: 0, log: today, history: history, unit: .lb), s("105", "6"))
        let after = Logging.setting(today, exercise: "Bench", index: 0, weight: "105", reps: "5")
        XCTAssertEqual(Logging.suggestion(exercise: bench, shownName: "Bench", index: 1, log: after, history: history, unit: .lb), s("105", "5")) // same as the set just done
        XCTAssertNil(Logging.suggestion(exercise: row, shownName: "Row", index: 0, log: today, history: history, unit: .lb))
        // history in pounds, shown in kilograms
        XCTAssertEqual(Logging.suggestion(exercise: bench, shownName: "Bench", index: 0, log: today, history: history, unit: .kg)?.weight, "47.9") // 45.4 + 2.5
    }

    func testLastTimeIgnoresTodayAndLater() {
        let history = [
            WorkoutLog(date: "2026-10-21", dayName: "Push", dayIndex: 1, sets: ["Bench": [s("60", "5")]]),
            WorkoutLog(date: "2026-10-28", dayName: "Push", dayIndex: 1, sets: ["Bench": [s("99", "9")]]),
        ]
        XCTAssertEqual(Logging.lastTime(name: "Bench", history: history, before: "2026-10-28", unit: .kg)?.date, "2026-10-21")
        XCTAssertNil(Logging.lastTime(name: "Squat", history: history, before: "2026-10-28", unit: .kg))
    }

    func testRestStartsWhenASetIsLoggedExceptTheVeryLastOne() {
        let empty = WorkoutLog(date: "2026-10-28", dayName: "Push", dayIndex: 1)
        let one = Logging.setting(empty, exercise: "Bench", index: 0, weight: "60", reps: "5")
        XCTAssertTrue(Logging.shouldStartRest(before: empty, after: one, exercise: bench, index: 0, day: day))
        let weightOnly = Logging.setting(empty, exercise: "Bench", index: 0, weight: "60")
        XCTAssertFalse(Logging.shouldStartRest(before: empty, after: weightOnly, exercise: bench, index: 0, day: day)) // typing a weight is not a logged set
        let edited = Logging.setting(one, exercise: "Bench", index: 0, reps: "6")
        XCTAssertFalse(Logging.shouldStartRest(before: one, after: edited, exercise: bench, index: 0, day: day)) // fixing a typo does not restart rest
        let last = Logging.setting(empty, exercise: "Row", index: 1, weight: "50", reps: "8") // last set of the last exercise
        XCTAssertFalse(Logging.shouldStartRest(before: empty, after: last, exercise: row, index: 1, day: day))
        let notLast = Logging.setting(empty, exercise: "Bench", index: 2, weight: "60", reps: "5") // last set, but more exercises follow
        XCTAssertTrue(Logging.shouldStartRest(before: empty, after: notLast, exercise: bench, index: 2, day: day))
    }

    func testACopiedTemplateOverridesThePlanDay() {
        let copy = TemplateDay(day: 1, name: "Their push", exercises: [bench])
        let log = WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 1, template: copy)
        XCTAssertEqual(Logging.day(for: log, plan: [day], fallback: day).name, "Their push")
        XCTAssertEqual(Logging.day(for: WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 1), plan: [day], fallback: day).name, "Push")
    }
}

final class LoggingRowsTests: XCTestCase {
    func testRowsAreOnePerPlannedSetWithEmptyOnesWhereNothingIsLogged() {
        let e = TemplateExercise(name: "Bench", sets: 3, reps: "5")
        let log = Logging.setting(WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 1), exercise: "Bench", index: 1, weight: "60", reps: "5")
        XCTAssertEqual(Logging.rows(log, exercise: e), [SetLog(), SetLog(weight: "60", reps: "5"), SetLog()])
        XCTAssertEqual(Logging.rows(WorkoutLog(date: "2026-10-28", dayName: "x"), exercise: e).count, 3)
    }

    func testFormatSets() {
        XCTAssertEqual(Plan.formatSets([SetLog(weight: "100", reps: "8"), SetLog(weight: "100", reps: "8"), SetLog(weight: "100", reps: "7")], unit: .lb), "100lb × 8, 8, 7")
        XCTAssertEqual(Plan.formatSets([SetLog(weight: "", reps: "12")]), "12")
    }
}

final class SwapAndProfileTests: XCTestCase {
    func testASwapIsForTodayOnlyAndCanBeUndone() {
        let log = WorkoutLog(date: "2026-10-28", dayName: "x", dayIndex: 1, sets: ["Bench": [SetLog(weight: "60", reps: "5")]])
        let swapped = Logging.swapped(log, original: "Bench", to: "  Dumbbell press ")
        XCTAssertEqual(swapped.swaps, ["Bench": "Dumbbell press"])
        XCTAssertEqual(swapped.sets, log.sets) // the sets already typed stay under the plan's name
        XCTAssertEqual(Plan.effectiveName(swapped, "Bench"), "Dumbbell press")
        XCTAssertNil(Logging.swapped(swapped, original: "Bench", to: "Bench").swaps)
        XCTAssertNil(Logging.swapped(swapped, original: "Bench", to: "").swaps)
    }

    func testProfileFieldsUseDottedPathsAndMarkRemovedOnesNil() {
        let p = Profile(name: "Me", units: .imperial, gymUnit: .lb, heightCm: 175, goal: .lose, sex: .male, age: 30, weightKg: 80)
        let targets = Nutrition.computeTargets(p, autoSessions: 3)
        let f = p.updateFields(targets: targets)
        XCTAssertEqual(f["profile.heightCm"] as? Double, 175)
        XCTAssertEqual(f["profile.gymUnit"] as? String, "lb")
        XCTAssertEqual(f["profile.proteinMin"] as? Int, targets?.proteinMin)
        XCTAssertTrue(f.keys.contains("profile.targetDate")); XCTAssertNil(f["profile.targetDate"] ?? nil) // present with no value = remove it
        XCTAssertFalse(p.updateFields(targets: nil).keys.contains("profile.proteinMin"))
    }
}
