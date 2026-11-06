import XCTest
@testable import Fit2216Core

final class SummaryTests: XCTestCase {
    private let wed = day(2026, 10, 28)
    private let plan: [TemplateDay] = [
        TemplateDay(day: 1, name: "Push", exercises: [TemplateExercise(name: "Bench press", sets: 2, reps: "8"), TemplateExercise(name: "Triceps pushdown", sets: 2, reps: "10")]),
        TemplateDay(day: 2, name: "Pull", exercises: [TemplateExercise(name: "Lat pulldown", sets: 2, reps: "8")]),
        TemplateDay(day: 3, name: "Legs", exercises: [TemplateExercise(name: "Barbell squats", sets: 4, reps: "5")]),
        restDay(4),
    ]

    func testTodayCardStates() {
        let notStarted = Summary.today(plan: plan, logs: [], wed, cal)!
        XCTAssertEqual(notStarted.day.name, "Legs"); XCTAssertEqual(notStarted.state, .notStarted); XCTAssertEqual(notStarted.plannedSets, 4); XCTAssertTrue(notStarted.isToday)
        let started = WorkoutLog(date: "2026-10-28", dayName: "Legs", dayIndex: 3, sets: ["Barbell squats": [SetLog(weight: "100", reps: "5")]])
        let mid = Summary.today(plan: plan, logs: [started], wed, cal)!
        XCTAssertEqual(mid.state, .inProgress); XCTAssertEqual(mid.loggedSets, 1)
        var done = started; done.done = true
        XCTAssertEqual(Summary.today(plan: plan, logs: [done], wed, cal)?.state, .finished)
        var skipped = started; skipped.skipped = true
        XCTAssertEqual(Summary.today(plan: plan, logs: [skipped], wed, cal)?.state, .skipped)
        XCTAssertEqual(Summary.today(plan: plan, logs: [], day(2026, 10, 29), cal)?.state, .rest) // Thursday is a rest day
    }

    func testTargetMusclesListPrimaryFirst() {
        let push = Summary.today(plan: plan, logs: [], day(2026, 10, 26), cal)!
        XCTAssertEqual(push.muscles.prefix(2).map(\.rawValue).sorted(), ["chest", "triceps"])
        XCTAssertEqual(push.muscles.last, .shoulders) // a helper comes last
    }

    func testADayWithNoEntryShowsTheNextPlannedDay() {
        let tueOnly = [TemplateDay(day: 1, name: "A", exercises: [TemplateExercise(name: "Row", sets: 2, reps: "8")]), TemplateDay(day: 5, name: "C", exercises: [TemplateExercise(name: "Squat", sets: 2, reps: "8")])]
        let s = Summary.today(plan: tueOnly, logs: [doneLog("2026-10-26", 1, "A")], day(2026, 10, 27), cal)! // Tuesday, no entry, Monday done
        XCTAssertEqual(s.day.name, "C"); XCTAssertFalse(s.isToday)
        XCTAssertNil(Summary.today(plan: [], logs: [], wed, cal))
    }

    // MARK: streak

    func testStreakCountsHandledTrainingDaysAndStopsAtAMiss() {
        let logs = [doneLog("2026-10-26", 1, "Push"), doneLog("2026-10-27", 2, "Pull"), doneLog("2026-10-28", 3, "Legs")]
        XCTAssertEqual(Summary.streak(plan: plan, logs: logs, wed, cal), 3)
        // Today not done yet: the streak stands at 2 and today does not break it
        XCTAssertEqual(Summary.streak(plan: plan, logs: Array(logs.prefix(2)), wed, cal), 2)
        // Tuesday missed: only today's run counts
        XCTAssertEqual(Summary.streak(plan: plan, logs: [logs[0], logs[2]], wed, cal), 1)
        XCTAssertEqual(Summary.streak(plan: plan, logs: [], wed, cal), 0)
    }

    func testRestDaysAndSkippedDaysDoNotBreakIt() {
        // Friday: Thursday is a rest day, Wednesday done, Tuesday skipped on purpose, Monday done
        let logs = [doneLog("2026-10-26", 1, "Push"),
                    WorkoutLog(date: "2026-10-27", dayName: "Pull", dayIndex: 2, skipped: true),
                    doneLog("2026-10-28", 3, "Legs")]
        XCTAssertEqual(Summary.streak(plan: plan, logs: logs, day(2026, 10, 30), cal), 2)
    }
}
