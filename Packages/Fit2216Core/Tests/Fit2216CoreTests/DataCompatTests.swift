import XCTest
@testable import Fit2216Core

final class DataCompatTests: XCTestCase {
    func testKeystrokeLeftoversAreDropped() {
        let lib = ["B", "Ba", "Barb", "Barbell squats", "Bench", "Bench P", "Bench Press", "Dips", "Hip", "Hip thrust"]
        XCTAssertEqual(ExerciseLibrary.cleaned(lib), ["Barbell squats", "Bench Press", "Dips", "Hip thrust"])
    }
    func testPlanNamesAlwaysKept() {
        XCTAssertEqual(ExerciseLibrary.cleaned(["Hip", "Hip thrust"], keeping: ["Hip"]), ["Hip", "Hip thrust"])
    }
    func testCaseRepeatsKeepPlanSpelling() {
        XCTAssertEqual(ExerciseLibrary.cleaned(["Cable fly", "Cable Fly"], keeping: ["Cable Fly"]), ["Cable Fly"])
    }
    func testBlankAndEmpty() {
        XCTAssertEqual(ExerciseLibrary.cleaned(["", "  ", "Plank"]), ["Plank"])
        XCTAssertEqual(ExerciseLibrary.cleaned([]), [])
    }
    func testOldNamesJoinNewOnes() {
        XCTAssertEqual(ExerciseNames.canonical("Flat barbell bench press"), "Bench Press")
        XCTAssertEqual(ExerciseNames.key("High-to-low cable fly"), ExerciseNames.key("Cable Fly (H2L)"))
        XCTAssertEqual(ExerciseNames.canonical("Machine shoulder press"), "Shoulder press")
    }
}
