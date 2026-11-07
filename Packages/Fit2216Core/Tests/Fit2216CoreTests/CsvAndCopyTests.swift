import XCTest
@testable import Fit2216Core

final class CsvAndCopyTests: XCTestCase {
    private let logs: [WorkoutLog] = [
        WorkoutLog(date: "2026-10-14", dayName: "Push, heavy", dayIndex: 1, unit: .lb, done: true,
                   sets: ["Bench \"flat\"": [SetLog(weight: "135", reps: "6"), SetLog(weight: "135", reps: "5")], "Fly": [SetLog(weight: "30", reps: "12")]]),
        WorkoutLog(date: "2026-10-15", dayName: "Rest", dayIndex: 2, skipped: true),
    ]

    func testRoundTripKeepsWorkoutsAndWeighInsIncludingCommasAndQuotes() throws {
        let out = try Csv.parse(Csv.export(logs: logs, weights: [WeightEntry(date: "2026-10-14", kg: 80.5)]))
        XCTAssertEqual(out.logs.count, 2)
        XCTAssertEqual(out.logs[0].dayName, "Push, heavy")
        XCTAssertEqual(out.logs[0].sets["Bench \"flat\""]?.count, 2)
        XCTAssertEqual(out.logs[0].unit, .lb); XCTAssertEqual(out.logs[0].done, true)
        XCTAssertEqual(out.logs[1].skipped, true); XCTAssertEqual(out.logs[1].unit, .kg)
        XCTAssertEqual(out.weights, [WeightEntry(date: "2026-10-14", kg: 80.5)])
    }

    func testRejectsFilesThatAreNotOursOrHaveBadRows() {
        let head = Csv.header.joined(separator: ",")
        func err(_ body: String) -> String { (try? Csv.parse("\(head)\r\n\(body)")) == nil ? "threw" : "ok" }
        XCTAssertThrowsError(try Csv.parse("a,b\n1,2")) { XCTAssertEqual(($0 as? CsvError)?.message, "Not a Fit2216 CSV") }
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nweight,2026-02-30,,,,,80,,kg,,")) { XCTAssertTrue(($0 as! CsvError).message.hasPrefix("Row 2")) }
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nweight,2026-10-01,,,,,-4,,kg,,")) { XCTAssertTrue(($0 as! CsvError).message.contains("bad weight")) }
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nset,2026-10-01,1,Push,Bench,1,100,5,stone,,")) { XCTAssertTrue(($0 as! CsvError).message.contains("unit")) }
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nset,2026-10-01,9,Push,Bench,1,100,5,kg,,")) { XCTAssertTrue(($0 as! CsvError).message.contains("day_index")) }
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nset,2026-10-01,1,Push,\"Bench,1,100,5,kg,,")) { XCTAssertEqual(($0 as! CsvError).message, "Unclosed quote") }
    }

    func testMixedUnitsAndBothFlagsAreRejectedAndAFlagCountsFromAnyRow() throws {
        let head = Csv.header.joined(separator: ",")
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nset,2026-10-27,1,Push,Squat,1,100,5,lb,,\r\nset,2026-10-27,1,Push,Squat,2,100,5,kg,,")) { XCTAssertTrue(($0 as! CsvError).message.contains("mix kg and lb")) }
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nset,2026-10-27,1,Push,Squat,1,100,5,kg,yes,yes")) { XCTAssertTrue(($0 as! CsvError).message.contains("both finished and skipped")) }
        let out = try Csv.parse("\(head)\r\nset,2026-10-27,1,Push,Squat,1,100,5,kg,,\r\nset,2026-10-27,1,Push,Squat,2,100,5,kg,yes,")
        XCTAssertEqual(out.logs[0].done, true)
    }

    func testTextThatCouldRunAsAFormulaIsEscaped() {
        XCTAssertTrue(Csv.export(logs: [WorkoutLog(date: "2026-10-14", dayName: "=SUM(A1)")], weights: []).contains("'=SUM(A1)"))
        XCTAssertEqual(Csv.cell("-5"), "-5") // a plain number is left alone
    }

    func testBadWeightAndRepsCellsAreRejectedWithTheCellInTheMessage() throws {
        let head = Csv.header.joined(separator: ",")
        func message(_ weight: String, _ reps: String, unit: String = "kg") -> String? {
            do { _ = try Csv.parse("\(head)\r\nset,2026-10-01,1,Push,Bench,1,\(weight),\(reps),\(unit),,"); return nil } catch { return (error as? CsvError)?.message }
        }
        XCTAssertTrue(message("abc", "5")?.contains("bad weight") == true)
        XCTAssertTrue(message("-5", "5")?.contains("bad weight") == true)
        XCTAssertTrue(message("1e3", "5")?.contains("bad weight") == true)
        XCTAssertTrue(message("\"12,5\"", "5")?.contains("bad weight") == true)  // a decimal comma, quoted so it stays one cell
        XCTAssertTrue(message("5000", "5")?.contains("bad weight") == true)
        XCTAssertTrue(message("100", "8.5")?.contains("bad reps") == true)
        XCTAssertTrue(message("100", "x")?.contains("bad reps") == true)
        XCTAssertTrue(message("100", "-1")?.contains("bad reps") == true)
        XCTAssertNil(message("100.5", "8"))
        XCTAssertNil(message("", ""))           // an empty set keeps its place
        XCTAssertNil(message("", "12"))         // bodyweight
        XCTAssertNil(message("2000", "5", unit: "lb"))
    }

    func testNamesRowsAndDatesAreBounded() throws {
        let head = Csv.header.joined(separator: ",")
        let long = String(repeating: "a", count: 101)
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nset,2026-10-01,1,Push,\(long),1,100,5,kg,,")) { XCTAssertTrue(($0 as! CsvError).message.contains("longer than")) }
        XCTAssertThrowsError(try Csv.parse("\(head)\r\nweight,1850-01-01,,,,,80,,kg,,")) { XCTAssertTrue(($0 as! CsvError).message.contains("bad date")) }
        let many = (0..<50_001).map { _ in "weight,2026-10-01,,,,,80,,kg,," }.joined(separator: "\r\n")
        XCTAssertThrowsError(try Csv.parse("\(head)\r\n\(many)")) { XCTAssertTrue(($0 as! CsvError).message.contains("more than")) }
    }

    func testAFormulaLookingNameSurvivesAnExportAndImport() throws {
        let log = WorkoutLog(date: "2026-10-14", dayName: "=SUM(A1)", dayIndex: 1, sets: ["+cmd": [SetLog(weight: "50", reps: "8")]])
        let back = try Csv.parse(Csv.export(logs: [log], weights: [])).logs[0]
        XCTAssertEqual(back.dayName, "=SUM(A1)")
        XCTAssertEqual(back.sets["+cmd"]?.count, 1)
        XCTAssertEqual(Csv.unescape("'normal"), "'normal") // an apostrophe the export did not add is kept
    }

    func testWindowsLineEndingsBlankLinesAndABOMAreAccepted() throws {
        let head = Csv.header.joined(separator: ",")
        let out = try Csv.parse("\u{FEFF}\(head)\r\n\r\nweight,2026-10-14,,,,,80,,kg,,\r\n")
        XCTAssertEqual(out.weights.count, 1)
    }

    // MARK: copy-workout

    func testACopyCarriesTargetsAndSwapsButNoSetsOrCompletion() {
        let source = TemplateDay(day: 1, name: "Push", exercises: [TemplateExercise(name: "Bench", sets: 3, reps: "4–6", restSec: 180)])
        let theirs = WorkoutLog(date: "2026-10-14", dayName: "Push", dayIndex: 1, unit: .lb, done: true, sets: ["Bench": [SetLog(weight: "200", reps: "6")]], swaps: ["Bench": "DB press"])
        let copy = WorkoutCopy.copy(source: source, logged: theirs, date: "2026-10-14", dayIndex: 3)
        XCTAssertEqual(copy.dayIndex, 3); XCTAssertEqual(copy.sets, [:]); XCTAssertEqual(copy.swaps, ["Bench": "DB press"])
        XCTAssertEqual(copy.done, false); XCTAssertEqual(copy.skipped, false); XCTAssertNil(copy.unit)
        XCTAssertEqual(copy.template?.day, 3); XCTAssertEqual(copy.template?.exercises, source.exercises)
        XCTAssertEqual(source.day, 1) // the source is untouched
    }

    func testACopyCountsCompletionAgainstItsOwnTargetsNotThePlan() {
        let source = TemplateDay(day: 1, name: "Push", exercises: [TemplateExercise(name: "Bench", sets: 3, reps: "4–6")])
        var copied = WorkoutCopy.copy(source: source, logged: nil, date: "2026-10-14", dayIndex: 3)
        copied.sets = ["Bench": [SetLog(weight: "10", reps: "6"), SetLog(weight: "10", reps: "6"), SetLog(weight: "10", reps: "6")]]
        let stats = Insights.weeklyStats([copied], plan: [restDay(3)], day(2026, 10, 14), weeks: 1, cal)
        XCTAssertEqual(stats[0].volume, 180); XCTAssertEqual(stats[0].workouts, 1)
    }
}
