import XCTest
@testable import Fit2216Core

final class ProgressionCheckTests: XCTestCase {
    private let squat = TemplateExercise(name: "Squat", sets: 3, reps: "6–8")
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }
    private func log(_ date: String, _ rows: [SetLog], name: String = "Squat", unit: WeightUnit? = .kg, skipped: Bool? = nil, swaps: [String: String]? = nil) -> WorkoutLog {
        WorkoutLog(date: date, dayName: "A", dayIndex: 1, unit: unit, skipped: skipped, sets: [name: rows], swaps: swaps)
    }
    private func check(_ logs: [WorkoutLog], _ ex: TemplateExercise? = nil, unit: WeightUnit = .kg) -> ProgressionCheck.Advice {
        ProgressionCheck.evaluate(ex ?? squat, logs: logs, before: "2026-10-28", unit: unit, cal)
    }

    func testEligibleOnlyWhenEveryPrescribedSetReachesTheTopAtOneLoad() {
        let a = check([log("2026-10-26", [s("100", "8"), s("100", "8"), s("100", "9")])])
        XCTAssertEqual(a.status, .eligibleToIncrease); XCTAssertEqual(a.reason, .allSetsReachedTarget)
        XCTAssertEqual(a.evidence.load, 100); XCTAssertEqual(a.evidence.reps, [8, 8, 9]); XCTAssertEqual(a.evidence.targetReps, 8)
        XCTAssertEqual(a.evidence.date, "2026-10-26")
    }

    func testOneShortSetHolds() {
        let a = check([log("2026-10-26", [s("100", "8"), s("100", "8"), s("100", "7")])])
        XCTAssertEqual(a.status, .hold); XCTAssertEqual(a.reason, .repsBelowTarget)
    }

    func testFewerSetsThanPrescribedHolds() {
        let a = check([log("2026-10-26", [s("100", "8"), s("100", "8"), s("", "")])])
        XCTAssertEqual(a.reason, .incompleteSets); XCTAssertEqual(a.evidence.reps, [8, 8])
    }

    func testMixedLoadsHold() {
        XCTAssertEqual(check([log("2026-10-26", [s("100", "8"), s("105", "8"), s("100", "8")])]).reason, .unevenLoads)
        XCTAssertEqual(check([log("2026-10-26", [s("0", "8"), s("100", "8"), s("100", "8")])]).reason, .unevenLoads)
    }

    func testBodyweightOrZeroLoadIsNeverAnIncrease() {
        let pull = TemplateExercise(name: "Pull-up", sets: 2, reps: "8")
        XCTAssertEqual(check([log("2026-10-26", [s("", "10"), s("", "10")], name: "Pull-up")], pull).reason, .noLoad)
        XCTAssertEqual(check([log("2026-10-26", [s("0", "10"), s("0", "10")], name: "Pull-up")], pull).status, .hold)
    }

    func testInvalidValuesHold() {
        XCTAssertEqual(check([log("2026-10-26", [s("abc", "8"), s("100", "8"), s("100", "8")])]).reason, .invalidEntry)
        XCTAssertEqual(check([log("2026-10-26", [s("100", "8x"), s("100", "8"), s("100", "8")])]).reason, .invalidEntry)
        XCTAssertEqual(check([log("2026-10-26", [s("-5", "8"), s("100", "8"), s("100", "8")])]).reason, .invalidEntry)
    }

    func testExtraSetsBeyondThePlanAreNotJudged() {
        let a = check([log("2026-10-26", [s("100", "8"), s("100", "8"), s("100", "8"), s("100", "3")])])
        XCTAssertEqual(a.status, .eligibleToIncrease); XCTAssertEqual(a.evidence.reps.count, 3)
    }

    func testRepRangeFormatsAndNoTarget() {
        let side = TemplateExercise(name: "Lunge", sets: 1, reps: "10–15/side")
        XCTAssertEqual(check([log("2026-10-26", [s("20", "15")], name: "Lunge")], side).status, .eligibleToIncrease)
        XCTAssertEqual(check([log("2026-10-26", [s("20", "14")], name: "Lunge")], side).status, .hold)
        let amrap = TemplateExercise(name: "Squat", sets: 1, reps: "AMRAP")
        XCTAssertEqual(check([log("2026-10-26", [s("100", "20")])], amrap).reason, .noRepTarget)
    }

    func testLatestSessionDecidesEvenIfAnOlderOneQualified() {
        let a = check([log("2026-10-19", [s("100", "8"), s("100", "8"), s("100", "8")]), log("2026-10-26", [s("100", "8"), s("100", "6"), s("100", "6")])])
        XCTAssertEqual(a.reason, .repsBelowTarget); XCTAssertEqual(a.evidence.date, "2026-10-26")
    }

    func testSkippedAndSwappedLatestSessionsHold() {
        let good = log("2026-10-19", [s("100", "8"), s("100", "8"), s("100", "8")])
        XCTAssertEqual(check([good, log("2026-10-26", [s("100", "8")], skipped: true)]).reason, .skippedLastTime)
        let swapped = WorkoutLog(date: "2026-10-26", dayName: "A", dayIndex: 1, sets: ["Squat": [s("60", "8"), s("60", "8"), s("60", "8")]], swaps: ["Squat": "Leg press"])
        let a = check([good, swapped])
        XCTAssertEqual(a.reason, .swappedLastTime); XCTAssertEqual(a.evidence.date, "2026-10-26")
    }

    func testTodaysPartialSessionAndFutureLogsAreIgnored() {
        let a = check([log("2026-10-26", [s("100", "8"), s("100", "8"), s("100", "8")]), log("2026-10-28", [s("105", "5")]), log("2026-10-30", [s("110", "1")])])
        XCTAssertEqual(a.status, .eligibleToIncrease); XCTAssertEqual(a.evidence.date, "2026-10-26")
    }

    func testStaleAndMissingHistory() {
        XCTAssertEqual(check([log("2026-10-06", [s("100", "8"), s("100", "8"), s("100", "8")])]).reason, .staleHistory)
        XCTAssertEqual(check([log("2026-10-07", [s("100", "8"), s("100", "8"), s("100", "8")])]).status, .eligibleToIncrease) // exactly 21 days
        XCTAssertEqual(check([]).status, .noData); XCTAssertEqual(check([]).reason, .noHistory)
    }

    func testLoadsAreComparedAndReportedInTheRequestedUnit() {
        let a = check([log("2026-10-26", [s("225", "8"), s("225", "8"), s("225", "8")], unit: .lb)], unit: .kg)
        XCTAssertEqual(a.status, .eligibleToIncrease); XCTAssertEqual(a.evidence.load, 102.1); XCTAssertEqual(a.evidence.unit, .kg)
        XCTAssertEqual(check([log("2026-10-26", [s("100", "8"), s("100", "8"), s("100", "8")], unit: nil)], unit: .lb).evidence.load, 220.5) // old logs are kg
    }

    func testNextWorkoutReusesPlanPickAndHonoursRestDays() {
        let wed = day(2026, 10, 28)
        let mon = TemplateDay(day: 1, name: "A", exercises: [squat, TemplateExercise(name: "Bench", sets: 1, reps: "5")])
        let plan = [mon, restDay(3)]
        let n = ProgressionCheck.nextWorkout(plan: plan, logs: [log("2026-10-19", [s("100", "8"), s("100", "8"), s("100", "8")])], unit: .kg, wed, cal)!
        XCTAssertEqual(n.picked, Plan.pick(plan, [], wed, cal)); XCTAssertTrue(n.picked.catchUp)
        XCTAssertEqual(n.advice.map(\.status), [.eligibleToIncrease, .noData])
        let doneMon = WorkoutLog(date: "2026-10-26", dayName: "A", dayIndex: 1, done: true)
        let rest = ProgressionCheck.nextWorkout(plan: plan, logs: [doneMon], unit: .kg, wed, cal)!
        XCTAssertEqual(rest.picked.day.type, .rest); XCTAssertTrue(rest.advice.isEmpty)
        XCTAssertNil(ProgressionCheck.nextWorkout(plan: [], logs: [], unit: .kg, wed, cal))
    }
}
