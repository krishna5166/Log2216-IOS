import XCTest
@testable import Fit2216Core

final class PlanTests: XCTestCase {
    private let wed = day(2026, 10, 28) // Wednesday; the week began Monday 26 Oct

    func testPlansSortMondayFirst() {
        XCTAssertEqual(Plan.sort([restDay(0), trainingDay(3, "C"), trainingDay(1, "A")]).map(\.day), [1, 3, 0])
    }

    func testRepRanges() {
        XCTAssertEqual(Plan.topReps("4–6"), 6); XCTAssertEqual(Plan.bottomReps("4–6"), 4)
        XCTAssertEqual(Plan.topReps("10–15/side"), 15); XCTAssertEqual(Plan.topReps("8"), 8); XCTAssertEqual(Plan.topReps("AMRAP"), 0)
    }

    func testHalfTheSetsCountsAsHandledButNotAsFinished() {
        let d = trainingDay(1, "A", sets: 4) // 4 planned sets
        var l = WorkoutLog(date: "2026-10-26", dayName: "A", dayIndex: 1, sets: ["A lift": [SetLog(weight: "50", reps: "8"), SetLog(weight: "50", reps: "8")]])
        XCTAssertTrue(Plan.isComplete(l, d))   // 2 of 4
        XCTAssertFalse(Plan.isFinished(l, d))
        l.sets["A lift"] = [SetLog(weight: "50", reps: "8")]
        XCTAssertFalse(Plan.isComplete(l, d))
        l.skipped = true
        XCTAssertTrue(Plan.isComplete(l, d)); XCTAssertFalse(Plan.isFinished(l, d))
    }

    func testOptionalExercisesDoNotCountTowardFinished() {
        let d = TemplateDay(day: 1, name: "A", exercises: [TemplateExercise(name: "Main", sets: 1, reps: "8"), TemplateExercise(name: "Extra", sets: 3, reps: "8", optional: true)])
        let l = WorkoutLog(date: "2026-10-26", dayName: "A", dayIndex: 1, sets: ["Main": [SetLog(weight: "1", reps: "8")]])
        XCTAssertTrue(Plan.isFinished(l, d)); XCTAssertEqual(Plan.plannedSets(d), 1)
    }

    // MARK: pick

    func testPicksTheEarliestUnhandledDayUpToToday() {
        let plan = [trainingDay(1, "Mon"), trainingDay(2, "Tue"), trainingDay(3, "Wed")]
        let p = Plan.pick(plan, [], wed, cal)!
        XCTAssertEqual(p.day.day, 1); XCTAssertTrue(p.catchUp)
        let after = Plan.pick(plan, [doneLog("2026-10-26", 1, "Mon")], wed, cal)!
        XCTAssertEqual(after.day.day, 2); XCTAssertTrue(after.catchUp)
        let todayOnly = Plan.pick(plan, [doneLog("2026-10-26", 1, "Mon"), doneLog("2026-10-27", 2, "Tue")], wed, cal)!
        XCTAssertEqual(todayOnly.day.day, 3); XCTAssertFalse(todayOnly.catchUp)
    }

    func testEverythingDoneReturnsTodaysDay() {
        let plan = [trainingDay(1, "Mon"), trainingDay(3, "Wed")]
        let p = Plan.pick(plan, [doneLog("2026-10-26", 1, "Mon"), doneLog("2026-10-28", 3, "Wed")], wed, cal)!
        XCTAssertEqual(p.day.day, 3); XCTAssertTrue(p.allDone)
    }

    func testAWorkoutInProgressStaysOpenInsteadOfJumpingOn() {
        let plan = [trainingDay(1, "Mon", sets: 4), trainingDay(3, "Wed", sets: 4)]
        let started = WorkoutLog(date: "2026-10-28", dayName: "Wed", dayIndex: 3, sets: ["Wed lift": [SetLog(weight: "5", reps: "8"), SetLog(weight: "5", reps: "8")]]) // half done = handled, but still open
        let p = Plan.pick(plan, [doneLog("2026-10-26", 1, "Mon"), started], wed, cal)!
        XCTAssertEqual(p.day.day, 3); XCTAssertFalse(p.allDone)
    }

    func testAMonWedFriPlanOnTuesday() {
        let plan = [trainingDay(1, "A"), trainingDay(3, "B"), trainingDay(5, "C")]
        let tue = day(2026, 10, 27)
        let undone = Plan.pick(plan, [], tue, cal)!
        XCTAssertEqual(undone.day.day, 1); XCTAssertTrue(undone.catchUp); XCTAssertFalse(undone.allDone)
        let after = Plan.pick(plan, [doneLog("2026-10-26", 1, "A")], tue, cal)!
        XCTAssertEqual(after.day.day, 3); XCTAssertTrue(after.allDone) // nothing due; Wednesday is next
    }

    func testAPlanWhoseDaysAllComeLaterPointsAtItsFirstDay() {
        XCTAssertEqual(Plan.pick([trainingDay(4, "A"), trainingDay(6, "B")], [], wed, cal)?.day.day, 4)
        XCTAssertEqual(Plan.pick([trainingDay(3, "A")], [], wed, cal)?.day.day, 3)
        XCTAssertEqual(Plan.pick([trainingDay(0, "Sun")], [], wed, cal)?.day.day, 0)
        XCTAssertNil(Plan.pick([], [], wed, cal))
    }

    func testAMissedEarlierDayIsACatchUpEvenWhenTodayHasNoEntry() {
        let p = Plan.pick([trainingDay(1, "A"), trainingDay(5, "C")], [], wed, cal)!
        XCTAssertEqual(p.day.day, 1); XCTAssertTrue(p.catchUp)
    }

    func testRestDaysAreNeverPicked() {
        let plan = [restDay(1), trainingDay(2, "B"), restDay(3)]
        XCTAssertEqual(Plan.pick(plan, [], wed, cal)?.day.day, 2)
    }

    // MARK: missed / next

    func testMissedDaysAreEarlierTrainingDaysNotDone() {
        let plan = [trainingDay(1, "Mon"), trainingDay(2, "Tue"), restDay(3), trainingDay(4, "Thu")]
        let missed = Plan.missedDays(plan, [doneLog("2026-10-26", 1, "Mon")], wed, cal)
        XCTAssertEqual(missed.map(\.day), [2])
    }

    func testNextUpSkipsDoneDaysAndWrapsToTheWeeksFirst() {
        let plan = [trainingDay(1, "A"), trainingDay(3, "B"), trainingDay(5, "C")]
        XCTAssertEqual(Plan.nextUp(plan, [], wed, afterDay: 1, cal)?.day, 3)
        XCTAssertEqual(Plan.nextUp(plan, [doneLog("2026-10-28", 3, "B")], wed, afterDay: 1, cal)?.day, 5)
        XCTAssertEqual(Plan.nextUp(plan, [], wed, afterDay: 5, cal)?.day, 1)
        XCTAssertNil(Plan.nextUp([restDay(1)], [], wed, afterDay: 1, cal))
    }

    // MARK: per-exercise helpers

    func testRecentSessionsSwapsAndUnits() {
        let logs = [
            WorkoutLog(date: "2026-10-20", dayName: "A", dayIndex: 1, unit: .lb, sets: ["Bench": [SetLog(weight: "100", reps: "8")]]),
            WorkoutLog(date: "2026-10-13", dayName: "A", dayIndex: 1, unit: .kg, sets: ["Press": [SetLog(weight: "40", reps: "8")]], swaps: ["Press": "Bench"]),
            WorkoutLog(date: "2026-10-27", dayName: "A", dayIndex: 1, sets: ["Bench": [SetLog(weight: "1", reps: "1")]]),
        ]
        let s = Plan.recentSessions(logs, name: "Bench", before: "2026-10-27", unit: .kg)
        XCTAssertEqual(s.map(\.date), ["2026-10-20", "2026-10-13"]) // today's and later are excluded; the swapped log counts under the name done
        XCTAssertEqual(s[0].sets[0].weight, "45.4") // 100 lb shown in kg
        XCTAssertEqual(s[1].sets[0].weight, "40")
    }

    func testReadyToIncreaseNeedsEverySetAtTheTop() {
        let ex = TemplateExercise(name: "Bench", sets: 2, reps: "4–6")
        XCTAssertTrue(Plan.readyToIncrease(ex, [SetLog(weight: "100", reps: "6"), SetLog(weight: "100", reps: "6")]))
        XCTAssertFalse(Plan.readyToIncrease(ex, [SetLog(weight: "100", reps: "6"), SetLog(weight: "100", reps: "5")]))
        XCTAssertFalse(Plan.readyToIncrease(ex, [SetLog(weight: "100", reps: "6")]))
        XCTAssertFalse(Plan.readyToIncrease(ex, nil))
    }

    func testRestSecondsAndClock() {
        XCTAssertEqual(Plan.restSeconds(TemplateExercise(name: "Squat", sets: 3, reps: "4–6")), 180)
        XCTAssertEqual(Plan.restSeconds(TemplateExercise(name: "Row", sets: 3, reps: "8–10")), 120)
        XCTAssertEqual(Plan.restSeconds(TemplateExercise(name: "Curl", sets: 3, reps: "12–15")), 90)
        XCTAssertEqual(Plan.restSeconds(TemplateExercise(name: "Devil Press", sets: 1, reps: "5")), 90)
        XCTAssertEqual(Plan.restSeconds(TemplateExercise(name: "Squat", sets: 3, reps: "4–6", restSec: 45)), 45)
        XCTAssertEqual(Plan.clock(125), "2:05"); XCTAssertEqual(Plan.clock(-3), "0:00"); XCTAssertEqual(Plan.clock(59.2), "1:00")
    }

    func testStepAndSuggestSet() {
        XCTAssertEqual(Plan.step("", fallback: 100, delta: 5), "105")
        XCTAssertEqual(Plan.step("2.5", fallback: 0, delta: -5), "0")
        XCTAssertEqual(Plan.step("0.1", fallback: 0, delta: 0.2), "0.3") // no float noise
        let last = [SetLog(weight: "100", reps: "6")]
        XCTAssertEqual(Plan.suggestSet(current: nil, index: 0, last: last, ready: true, step: 5), SetLog(weight: "105", reps: "6"))
        XCTAssertEqual(Plan.suggestSet(current: nil, index: 0, last: last, ready: false, step: 5), SetLog(weight: "100", reps: "6"))
        XCTAssertEqual(Plan.suggestSet(current: [SetLog(weight: "110", reps: "5")], index: 1, last: last, ready: true, step: 5), SetLog(weight: "110", reps: "5"))
        XCTAssertNil(Plan.suggestSet(current: nil, index: 0, last: nil, ready: false, step: 5))
    }
}
