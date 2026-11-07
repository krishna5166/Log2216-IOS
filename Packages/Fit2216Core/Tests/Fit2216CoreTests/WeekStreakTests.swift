import XCTest
@testable import Fit2216Core

/// The streak counts weeks (Monday to Sunday) in which every planned workout was done, on any days and in any order.
final class WeekStreakTests: XCTestCase {
    private let plan = [trainingDay(1, "A"), trainingDay(2, "B"), trainingDay(3, "C"), trainingDay(4, "D"), trainingDay(5, "E")]
    private let names = [1: "A", 2: "B", 3: "C", 4: "D", 5: "E"]

    /// Logs for the given plan days in the week that starts on `monday`, each done on `dates[i]` (days after Monday).
    private func week(_ monday: String, _ done: [Int], onOffsets offsets: [Int]? = nil) -> [WorkoutLog] {
        done.enumerated().map { i, d in
            let offset = offsets?[i] ?? (d - 1)                    // by default each session on its own weekday
            return doneLog(Dates.addDays(monday, offset, cal), d, names[d]!)
        }
    }
    private let thisMonday = "2026-10-26", lastMonday = "2026-10-19", beforeMonday = "2026-10-12"
    private let fridayThisWeek = day(2026, 10, 30), sundayThisWeek = day(2026, 11, 1)

    func testCompleteWeeksInARowIncludingTheCurrentOne() {
        let logs = week(thisMonday, [1, 2, 3, 4, 5]) + week(lastMonday, [1, 2, 3, 4, 5]) + week(beforeMonday, [1, 2, 3, 4, 5])
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: logs, fridayThisWeek, cal), 3)
    }

    func testAnUnfinishedCurrentWeekDoesNotBreakTheStreakOrGrowIt() {
        let logs = week(thisMonday, [1, 2, 3, 4]) + week(lastMonday, [1, 2, 3, 4, 5]) + week(beforeMonday, [1, 2, 3, 4, 5])
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: logs, fridayThisWeek, cal), 2)
    }

    func testAWeekShiftedByADayStillCounts() {
        // Monday missed; the whole plan done Tuesday to Saturday (rest fell on Monday): offsets 1 to 5 days after Monday.
        let shifted = week(thisMonday, [1, 2, 3, 4, 5], onOffsets: [1, 2, 3, 4, 5])
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: shifted, sundayThisWeek, cal), 1)
        // and it keeps a streak that was already running
        let more = shifted + week(lastMonday, [1, 2, 3, 4, 5])
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: more, sundayThisWeek, cal), 2)
    }

    func testOneMissedWorkoutInAFinishedWeekResetsTheStreak() {
        let logs = week(thisMonday, [1, 2, 3, 4, 5]) + week(lastMonday, [1, 2, 3, 4]) + week(beforeMonday, [1, 2, 3, 4, 5])
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: logs, fridayThisWeek, cal), 1) // only this week; last week broke it
        let broken = week(thisMonday, [1, 2]) + week(lastMonday, [1, 2, 3, 4])
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: broken, fridayThisWeek, cal), 0)
    }

    func testASkippedWorkoutCountsAsNotDone() {
        var skipped = doneLog("2026-10-22", 4, "D"); skipped.done = nil; skipped.skipped = true
        let lastWeek = week(lastMonday, [1, 2, 3, 5]) + [skipped]
        let logs = week(thisMonday, [1, 2, 3, 4, 5]) + lastWeek
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: logs, fridayThisWeek, cal), 1)
    }

    func testNoPlanOrNoWorkoutsIsZero() {
        XCTAssertEqual(Summary.weekStreak(plan: [], logs: [], fridayThisWeek, cal), 0)
        XCTAssertEqual(Summary.weekStreak(plan: plan, logs: [], fridayThisWeek, cal), 0)
        XCTAssertEqual(Summary.weekStreak(plan: [restDay(0), restDay(6)], logs: [], fridayThisWeek, cal), 0)
    }
}
