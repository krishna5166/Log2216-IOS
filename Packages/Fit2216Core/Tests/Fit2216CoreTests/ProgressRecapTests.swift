import XCTest
@testable import Fit2216Core

final class ProgressRecapTests: XCTestCase {
    private let now = day(2026, 10, 28) // Wednesday
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }
    private let bench = TemplateExercise(name: "Bench", sets: 2, reps: "4–6")
    private var plan: [TemplateDay] { [TemplateDay(day: 1, name: "Push", exercises: [bench]), restDay(2)] }
    private func log(_ date: String, _ sets: [SetLog]) -> WorkoutLog { WorkoutLog(date: date, dayName: "Push", dayIndex: 1, unit: .lb, done: true, sets: ["Bench": sets]) }

    // MARK: next week

    func testASessionAtTheTopOfTheRangeSuggestsOneStepMore() {
        let p = Progress.progression(plan: plan, logs: [log("2026-10-26", [s("100", "6"), s("100", "6")])], unit: .lb, now, cal)
        XCTAssertEqual(p.raise, [Raise(name: "Bench", from: 100, to: 105)])
        XCTAssertTrue(p.stalled.isEmpty); XCTAssertFalse(p.deload)
        // missing a rep, or a session older than three weeks, suggests nothing
        XCTAssertTrue(Progress.progression(plan: plan, logs: [log("2026-10-26", [s("100", "6"), s("100", "5")])], unit: .lb, now, cal).raise.isEmpty)
        XCTAssertTrue(Progress.progression(plan: plan, logs: [log("2026-09-20", [s("100", "6"), s("100", "6")])], unit: .lb, now, cal).raise.isEmpty)
    }

    func testAStalledLiftNeedsFourSessionsTwoWeeksAndNoNewBest() {
        // best early, then three flat sessions over 3 weeks
        let logs = [log("2026-09-01", [s("120", "5")]), log("2026-10-07", [s("100", "5")]), log("2026-10-14", [s("100", "5")]), log("2026-10-26", [s("100", "5")])]
        let p = Progress.progression(plan: plan, logs: logs, unit: .lb, now, cal)
        XCTAssertEqual(p.stalled.count, 1); XCTAssertEqual(p.stalled[0].name, "Bench"); XCTAssertEqual(p.stalled[0].sessions, 4)
        XCTAssertEqual(p.stalled[0].deloadTo, 90) // 90% of 100 lb, to the nearest 5
        XCTAssertFalse(p.deload) // one lift is not a deload
        // a new best in the last three means not stalled
        let better = logs + [log("2026-10-27", [s("130", "5")])]
        XCTAssertTrue(Progress.progression(plan: plan, logs: better, unit: .lb, now, cal).stalled.isEmpty)
        // three sessions in under two weeks is not enough time
        let quick = [log("2026-09-01", [s("120", "5")]), log("2026-10-20", [s("100", "5")]), log("2026-10-24", [s("100", "5")]), log("2026-10-26", [s("100", "5")])]
        XCTAssertTrue(Progress.progression(plan: plan, logs: quick, unit: .lb, now, cal).stalled.isEmpty)
    }

    func testTwoStalledLiftsSuggestADeload() {
        let two = [TemplateDay(day: 1, name: "Push", exercises: [bench, TemplateExercise(name: "Row", sets: 2, reps: "8")])]
        func both(_ d: String, _ w: String) -> WorkoutLog { WorkoutLog(date: d, dayName: "Push", dayIndex: 1, unit: .lb, done: true, sets: ["Bench": [s(w, "5")], "Row": [s(w, "5")]]) }
        let logs = [both("2026-09-01", "120"), both("2026-10-07", "100"), both("2026-10-14", "100"), both("2026-10-26", "100")]
        XCTAssertTrue(Progress.progression(plan: two, logs: logs, unit: .lb, now, cal).deload)
    }

    // MARK: recap

    func testWeekRecapCountsDoneFindsRecordsAndWeightChange() {
        let logs = [log("2026-10-12", [s("100", "5")]), log("2026-10-26", [s("110", "5")])] // a record on Monday 26 Oct
        let weights = [WeightEntry(date: "2026-10-23", kg: 80), WeightEntry(date: "2026-10-27", kg: 79.4)]
        let r = Recap.week(plan: plan, logs: logs, weights: weights, percents: ["2026-10-26": 80, "2026-10-27": 60], now, cal)
        XCTAssertEqual(r.label, "This week so far"); XCTAssertEqual(r.from, "2026-10-26"); XCTAssertEqual(r.to, "2026-11-01")
        XCTAssertEqual(r.done, 1); XCTAssertEqual(r.planned, 1)
        XCTAssertEqual(r.records.map(\.name), ["Bench"])
        XCTAssertEqual(r.latestKg, 79.4); XCTAssertEqual(r.changeKg ?? 0, -0.6, accuracy: 0.001)
        XCTAssertEqual(r.macroAvg, 70); XCTAssertEqual(r.macroDays, 2)
    }

    func testOnAMondayTheRecapIsLastWeekAndOnSundayThisWeek() {
        XCTAssertEqual(Recap.anchor(day(2026, 10, 26), cal).label, "Last week")
        XCTAssertEqual(Dates.localDate(Recap.anchor(day(2026, 10, 26), cal).start, cal), "2026-10-19")
        XCTAssertEqual(Recap.anchor(day(2026, 11, 1), cal).label, "This week")
    }

    func testCalendarWeeksMarkDonePartSkippedAndToday() {
        let logs = [log("2026-10-26", [s("100", "5")]),
                    WorkoutLog(date: "2026-10-20", dayName: "Push", dayIndex: 1, sets: ["Bench": [s("50", "5")]]),   // 1 of 2 sets: counts as handled (half)
                    WorkoutLog(date: "2026-10-21", dayName: "Push", dayIndex: 1, skipped: true)]
        let weeks = Recap.calendarWeeks(plan: plan, logs: logs, percents: ["2026-10-26": 90], now, weeks: 2, cal)
        XCTAssertEqual(weeks.count, 2); XCTAssertEqual(weeks[0].count, 7)
        XCTAssertEqual(weeks[1][0].trained, .done); XCTAssertEqual(weeks[1][0].macroPct, 90)
        XCTAssertTrue(weeks[1][2].today); XCTAssertTrue(weeks[1][3].future)
        XCTAssertEqual(weeks[0][1].trained, .done) // 20 Oct, half the sets
        XCTAssertEqual(weeks[0][2].trained, .skipped)
    }
}
