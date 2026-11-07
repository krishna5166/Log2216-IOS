import XCTest
@testable import Fit2216Core

final class WorkoutRecapTests: XCTestCase {
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }

    func testCountsSetsExercisesAndVolumeAndIgnoresUnloggedSets() {
        let log = WorkoutLog(date: "2026-11-06", dayName: "Push", dayIndex: 5, sets: [
            "Bench": [s("60", "10"), s("60", "8"), s("", "")],
            "Row": [s("50", "10")],
            "Curl": [s("", ""), s("", "")],
        ])
        let r = WorkoutRecap.result(log: log, lifts: [:])
        XCTAssertEqual(r.sets, 3)
        XCTAssertEqual(r.exercises, 2)
        let expected: Double = 600 + 480 + 500
        XCTAssertEqual(r.volumeKg, expected, accuracy: 0.001)
        XCTAssertTrue(r.records.isEmpty)
    }

    func testPoundsAreConvertedAndBodyweightRepsAddNoVolume() {
        let log = WorkoutLog(date: "2026-11-06", dayName: "Pull", dayIndex: 5, unit: .lb, sets: ["Pull-up": [s("", "8")], "Row": [s("100", "10")]])
        let r = WorkoutRecap.result(log: log, lifts: [:])
        XCTAssertEqual(r.sets, 2)
        XCTAssertEqual(r.volumeKg, 453.592, accuracy: 0.01)
    }

    func testReportsLiftsThatBeatTheirHistory() {
        let earlier = [WorkoutLog(date: "2026-10-01", dayName: "Push", dayIndex: 5, sets: ["Bench": [s("60", "8")]])]
        let today = WorkoutLog(date: "2026-11-06", dayName: "Push", dayIndex: 5, sets: ["Bench": [s("70", "8")]])
        let r = WorkoutRecap.result(log: today, lifts: Insights.liftHistory(earlier))
        XCTAssertEqual(r.records, ["Bench"])
    }
}
