import XCTest
@testable import Fit2216Core

final class UnitsAndDatesTests: XCTestCase {
    func testConversionsAndTidy() {
        XCTAssertEqual(Units.tidy(135), "135")
        XCTAssertEqual(Units.tidy(22.46), "22.5")
        XCTAssertEqual(Units.tidy(0.04), "0")
        XCTAssertEqual(Units.convertWeightString("100", from: .lb, to: .kg), "45.4")
        XCTAssertEqual(Units.convertWeightString("45.4", from: .kg, to: .lb), "100.1")
        XCTAssertEqual(Units.convertWeightString("", from: .lb, to: .kg), "")
        XCTAssertEqual(Units.convertWeightString("abc", from: .lb, to: .kg), "abc")
        XCTAssertEqual(Units.convertWeightString("100", from: .kg, to: .kg), "100")
    }

    func testLogsWithNoUnitAreKilograms() {
        XCTAssertEqual(Units.logUnit(WorkoutLog(date: "2026-10-01", dayName: "x")), .kg)
        XCTAssertEqual(Units.logUnit(WorkoutLog(date: "2026-10-01", dayName: "x", unit: .lb)), .lb)
    }

    func testWeekStartsOnMondayAndRunsToSunday() {
        // Wednesday 28 Oct 2026
        XCTAssertEqual(Dates.weekStart(day(2026, 10, 28), cal), "2026-10-26")
        XCTAssertEqual(Dates.weekStart(day(2026, 10, 26), cal), "2026-10-26") // Monday itself
        XCTAssertEqual(Dates.weekStart(day(2026, 11, 1), cal), "2026-10-26") // Sunday belongs to the week before
        let week = Dates.weekDates(day(2026, 10, 28), cal).map { Dates.localDate($0, cal) }
        XCTAssertEqual(week, ["2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01"])
    }

    func testWeekdayNumbersMatchThePlan() {
        XCTAssertEqual(Dates.weekday(day(2026, 11, 1), cal), 0) // Sunday
        XCTAssertEqual(Dates.weekday(day(2026, 10, 26), cal), 1) // Monday
        XCTAssertEqual(Dates.weekday(day(2026, 10, 31), cal), 6) // Saturday
    }

    func testTheWeekDoesNotSkipADayAcrossDaylightSaving() {
        // US clocks go back on Sun 1 Nov 2026
        let week = Dates.weekDates(day(2026, 11, 2), cal).map { Dates.localDate($0, cal) }
        XCTAssertEqual(week.first, "2026-11-02")
        XCTAssertEqual(Dates.weekDates(day(2026, 10, 28), cal).count, 7)
        XCTAssertEqual(Set(Dates.weekDates(day(2026, 10, 28), cal).map { Dates.localDate($0, cal) }).count, 7)
    }

    func testParseRejectsImpossibleDates() {
        XCTAssertNotNil(Dates.parse("2026-10-27", cal))
        XCTAssertNil(Dates.parse("2026-02-30", cal))
        XCTAssertNil(Dates.parse("26-10-27", cal))
        XCTAssertNil(Dates.parse("hello", cal))
    }
}
