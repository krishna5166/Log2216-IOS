import XCTest
@testable import Fit2216Core

/// A session done on a different day than planned (a missed Monday done on Friday, or Friday's done on Thursday)
/// is logged with the date it was done but the plan day it belongs to. It must count for that plan day this week.
final class CatchUpTests: XCTestCase {
    private let friday = day(2026, 10, 30)   // Monday of this week is 2026-10-26
    private let thursday = day(2026, 10, 29)
    private let plan = [trainingDay(1, "A"), trainingDay(2, "B"), trainingDay(3, "C"), trainingDay(4, "D"), trainingDay(5, "E")]

    private func state(_ week: WeekSummary, _ weekday: Int) -> WeekDay.State? { week.days.first { $0.weekday == weekday }?.state }

    func testAMissedMondayDoneOnFridayIsDoneNotMissed() {
        let logs = [doneLog("2026-10-27", 2, "B"), doneLog("2026-10-28", 3, "C"), doneLog("2026-10-29", 4, "D"),
                    doneLog("2026-10-30", 1, "A")] // Monday's session, done on Friday
        let week = Summary.week(plan: plan, logs: logs, friday, cal)
        XCTAssertEqual(state(week, 1), .done)
        XCTAssertEqual(week.done, 4)
        XCTAssertEqual(week.planned, 5)
        XCTAssertEqual(state(week, 5), .today) // Friday's own session is still to do
    }

    func testWithoutTheCatchUpMondayIsMissed() {
        let week = Summary.week(plan: plan, logs: [doneLog("2026-10-27", 2, "B")], friday, cal)
        XCTAssertEqual(state(week, 1), .missed)
    }

    func testFridaysSessionDoneEarlyOnThursdayIsDone() {
        let week = Summary.week(plan: plan, logs: [doneLog("2026-10-29", 5, "E")], thursday, cal)
        XCTAssertEqual(state(week, 5), .done)
    }

    func testLastWeeksSessionDoesNotCountForThisWeek() {
        let week = Summary.week(plan: plan, logs: [doneLog("2026-10-19", 1, "A")], friday, cal) // the Monday before
        XCTAssertEqual(state(week, 1), .missed)
    }

    func testASkippedDayLaterDoneCountsAsDone() {
        var skipped = doneLog("2026-10-26", 1, "A"); skipped.done = nil; skipped.skipped = true
        let week = Summary.week(plan: plan, logs: [skipped, doneLog("2026-10-30", 1, "A")], friday, cal)
        XCTAssertEqual(state(week, 1), .done)
        let onlySkipped = Summary.week(plan: plan, logs: [skipped], friday, cal)
        XCTAssertEqual(state(onlySkipped, 1), .skipped)
    }

    func testTheStreakCountsACatchUpDay() {
        let logs = [doneLog("2026-10-27", 2, "B"), doneLog("2026-10-28", 3, "C"), doneLog("2026-10-29", 4, "D"), doneLog("2026-10-30", 1, "A")]
        // Thursday, Wednesday, Tuesday and the caught-up Monday; Friday is today and not over; the Friday before has nothing.
        XCTAssertEqual(Summary.streak(plan: plan, logs: logs, friday, cal), 4)
        XCTAssertEqual(Summary.streak(plan: plan, logs: Array(logs.prefix(3)), friday, cal), 3) // without it the streak ends at the missed Monday
    }
}
