import XCTest
@testable import Fit2216Core

final class SummaryCardsTests: XCTestCase {
    private let wed = day(2026, 10, 28)
    private let plan: [TemplateDay] = [
        TemplateDay(day: 1, name: "Push", exercises: [TemplateExercise(name: "Bench press", sets: 2, reps: "8"), TemplateExercise(name: "Triceps pushdown", sets: 2, reps: "10")]),
        TemplateDay(day: 2, name: "Pull", exercises: [TemplateExercise(name: "Lat pulldown", sets: 2, reps: "8"), TemplateExercise(name: "Cable row", sets: 2, reps: "8", optional: true)]),
        TemplateDay(day: 3, name: "Legs", exercises: [TemplateExercise(name: "Barbell squats", sets: 4, reps: "5")]),
        TemplateDay(day: 4, name: "Arms", exercises: [TemplateExercise(name: "Hammer curls", sets: 2, reps: "10")]),
        restDay(6),
    ]
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }

    // MARK: week strip

    func testWeekMarksDoneMissedTodayAndUpcoming() {
        let logs = [doneLog("2026-10-26", 1, "Push")] // Monday done, Tuesday missed
        let week = Summary.week(plan: plan, logs: logs, wed, cal)
        XCTAssertEqual(week.days.map(\.state), [.done, .missed, .today, .upcoming, .none, .rest, .none])
        XCTAssertEqual(week.days.map(\.weekday), [1, 2, 3, 4, 5, 6, 0])
        XCTAssertEqual(week.done, 1); XCTAssertEqual(week.planned, 4)
        XCTAssertTrue(week.days[2].isToday)
    }

    func testASkippedDayIsNotDoneOrMissedAndHalfTheSetsCountAsDone() {
        let skipped = WorkoutLog(date: "2026-10-27", dayName: "Pull", dayIndex: 2, skipped: true)
        let half = WorkoutLog(date: "2026-10-28", dayName: "Legs", dayIndex: 3, sets: ["Barbell squats": [s("100", "5"), s("100", "5")]])
        let week = Summary.week(plan: plan, logs: [skipped, half], wed, cal)
        XCTAssertEqual(week.days[1].state, .skipped); XCTAssertEqual(week.days[2].state, .done)
        XCTAssertEqual(week.done, 1)
    }

    // MARK: what is left

    func testRemainingListsExercisesWithSetsLeftRequiredFirst() {
        let log = WorkoutLog(date: "2026-10-27", dayName: "Pull", dayIndex: 2, sets: ["Lat pulldown": [s("50", "8")]])
        let left = Summary.remaining(day: plan[1], log: log)
        XCTAssertEqual(left, [RemainingExercise(name: "Lat pulldown", setsLeft: 1, optional: false), RemainingExercise(name: "Cable row", setsLeft: 2, optional: true)])
        XCTAssertEqual(Summary.remaining(day: plan[2], log: nil).map(\.setsLeft), [4])
        let full = WorkoutLog(date: "2026-10-28", dayName: "Legs", dayIndex: 3, sets: ["Barbell squats": Array(repeating: s("100", "5"), count: 4)])
        XCTAssertEqual(Summary.remaining(day: plan[2], log: full), [])
    }

    func testRemainingUsesTodaysSwapName() {
        let log = WorkoutLog(date: "2026-10-28", dayName: "Legs", dayIndex: 3, sets: [:], swaps: ["Barbell squats": "Hack squats"])
        XCTAssertEqual(Summary.remaining(day: plan[2], log: log).first?.name, "Hack squats")
    }

    // MARK: body card

    func testBodyCardShowsLatestAveragePaceAndProjection() {
        let weights = [("2026-10-07", 80.0), ("2026-10-14", 79.5), ("2026-10-21", 79.0), ("2026-10-28", 78.5)].map { WeightEntry(date: $0.0, kg: $0.1) }
        let body = Summary.body(weights: weights, profile: Profile(heightCm: 175, targetWeightKg: 70), wed, cal)!
        XCTAssertEqual(body.latestKg, 78.5); XCTAssertEqual(body.latestDate, "2026-10-28")
        XCTAssertEqual(body.perWeekKg ?? 0, -0.5, accuracy: 0.01)
        XCTAssertEqual(body.baselineKg, 70)
        XCTAssertEqual(body.projection?.state, .on)
        XCTAssertNil(Summary.body(weights: [], profile: Profile(), wed, cal))
        let few = Summary.body(weights: [WeightEntry(date: "2026-10-28", kg: 80)], profile: Profile(), wed, cal)!
        XCTAssertNil(few.perWeekKg); XCTAssertNil(few.projection)
    }

    func testRecentBest() {
        let logs = [
            WorkoutLog(date: "2026-10-01", dayName: "x", dayIndex: 1, sets: ["Bench press": [s("80", "5")]]),
            WorkoutLog(date: "2026-10-27", dayName: "x", dayIndex: 1, sets: ["Bench press": [s("85", "5")]]),
        ]
        XCTAssertEqual(Summary.recentBest(logs: logs, wed, cal)?.weight, 85)
        XCTAssertNil(Summary.recentBest(logs: [], wed, cal))
    }

    // MARK: by muscle

    func testSetsCountMainMusclesFullAndHelpersHalf() {
        let logs = [WorkoutLog(date: "2026-10-27", dayName: "Push", dayIndex: 1, sets: ["Bench press": [s("80", "5"), s("80", "5"), s("80", "5"), s("80", "5")]])]
        let stats = MuscleInsights.stats(plan: plan, logs: logs, wed, cal)
        XCTAssertEqual(stats.first { $0.muscle == .chest }?.setsThisWeek, 4)
        XCTAssertEqual(stats.first { $0.muscle == .triceps }?.setsThisWeek, 2) // helper: half
        XCTAssertEqual(stats.first { $0.muscle == .chest }?.daysSince, 1)
        XCTAssertEqual(stats.first { $0.muscle == .chest }?.lastTrained, "2026-10-27")
    }

    func testTopLiftAndStrengthChangeOverTheLastEightWeeks() {
        let logs = [
            WorkoutLog(date: "2026-09-15", dayName: "Push", dayIndex: 1, sets: ["Bench press": [s("80", "5")]]),
            WorkoutLog(date: "2026-10-27", dayName: "Push", dayIndex: 1, sets: ["Bench press": [s("90", "5")], "Triceps pushdown": [s("40", "10")]]),
        ]
        let chest = MuscleInsights.stats(plan: plan, logs: logs, wed, cal).first { $0.muscle == .chest }!
        XCTAssertEqual(chest.topLift, "Bench press")
        XCTAssertEqual(chest.strengthChangeKg ?? 0, 10 * (1 + 5.0 / 30), accuracy: 0.01)
        XCTAssertEqual(chest.strengthChangePercent ?? 0, 12.5, accuracy: 0.01)
        // triceps are mainly worked by the pushdown, not by the bench press (a helper)
        XCTAssertEqual(MuscleInsights.stats(plan: plan, logs: logs, wed, cal).first { $0.muscle == .triceps }?.topLift, "Triceps pushdown")
    }

    func testRangeAgainstTypicalWeeklySets() {
        func range(_ sets: Int) -> MuscleStat.Range {
            let logs = [WorkoutLog(date: "2026-10-26", dayName: "Push", dayIndex: 1, sets: ["Bench press": Array(repeating: s("80", "5"), count: sets)])]
            return MuscleInsights.stats(plan: plan, logs: logs, wed, cal).first { $0.muscle == .chest }!.range
        }
        XCTAssertEqual(range(4), .low)    // 4 sets in 4 weeks = 1 a week
        XCTAssertEqual(range(40), .good)  // 10 a week
        XCTAssertEqual(range(100), .high) // 25 a week
    }

    func testSkippedLogsAndUnloggedMusclesAreIgnored() {
        let skipped = WorkoutLog(date: "2026-10-27", dayName: "Push", dayIndex: 1, skipped: true, sets: ["Bench press": [s("80", "5")]])
        XCTAssertTrue(MuscleInsights.stats(plan: plan, logs: [skipped], wed, cal).isEmpty)
        XCTAssertTrue(MuscleInsights.stats(plan: plan, logs: [], wed, cal).isEmpty)
    }

    func testBalanceFlags() {
        func logs(_ push: Int, _ pull: Int, date: String = "2026-10-27") -> [WorkoutLog] {
            [WorkoutLog(date: date, dayName: "x", dayIndex: 1, sets: ["Bench press": Array(repeating: s("80", "5"), count: push), "Lat pulldown": Array(repeating: s("50", "8"), count: pull)])]
        }
        func flags(_ l: [WorkoutLog]) -> [String] { MuscleInsights.balance(stats: MuscleInsights.stats(plan: plan, logs: l, wed, cal), plan: plan).map(\.title) }
        XCTAssertTrue(flags(logs(20, 4)).contains("Pushing more than pulling"))
        XCTAssertTrue(flags(logs(4, 20)).contains("Pulling more than pushing"))
        XCTAssertFalse(flags(logs(10, 10)).contains { $0.contains("more than") })
        // a muscle in the plan that has not been trained for 10+ days
        XCTAssertTrue(flags(logs(10, 10, date: "2026-10-10")).contains { $0.contains("not trained") })
    }
}
