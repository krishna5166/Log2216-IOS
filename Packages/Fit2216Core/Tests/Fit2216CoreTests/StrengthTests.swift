import XCTest
@testable import Fit2216Core

final class StrengthTests: XCTestCase {
    private let now = day(2026, 10, 28) // Wednesday; this week's Monday is 2026-10-26
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }
    private func log(_ date: String, _ sets: [String: [SetLog]]) -> WorkoutLog { WorkoutLog(date: date, dayName: "x", dayIndex: 1, sets: sets) }

    func testBlendsVolumeAndOneRepMax() {
        // week of 10-12: 100 kg x 5 x 2 sets; this week: 110 kg x 5 x 2 sets
        let logs = [log("2026-10-13", ["Squat": [s("100", "5"), s("100", "5")]]), log("2026-10-27", ["Squat": [s("110", "5"), s("110", "5")]])]
        let lift = Strength.lift("Squat", plan: [], logs: logs, now, weeks: 3, cal)
        XCTAssertEqual(lift.weeks.map(\.start), ["2026-10-12", "2026-10-19", "2026-10-26"])
        XCTAssertEqual(lift.weeks[0].score ?? 0, 100, accuracy: 0.001)
        XCTAssertNil(lift.weeks[1].score) // nothing lifted that week
        // volume +10% (index 1.10), e1RM +10% (1.10) -> 110
        XCTAssertEqual(lift.weeks[2].score ?? 0, 110, accuracy: 0.001)
        XCTAssertEqual(lift.weeks[2].volume, 1100, accuracy: 0.001)
    }

    func testVolumeIsTheMainSignal() {
        // same weight, double the sets: volume index 2.0, e1RM index 1.0 -> 100 * (0.7*2 + 0.3*1) = 170
        let logs = [log("2026-10-13", ["Bench": [s("80", "5")]]), log("2026-10-27", ["Bench": [s("80", "5"), s("80", "5")]])]
        let lift = Strength.lift("Bench", plan: [], logs: logs, now, weeks: 3, cal)
        XCTAssertEqual(lift.weeks[2].score ?? 0, 170, accuracy: 0.001)
        XCTAssertEqual(lift.weeks[2].volumeIndex ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(lift.weeks[2].e1rmIndex ?? 0, 100, accuracy: 0.001)
    }

    func testPoundsAreConvertedAndBodyweightSetsIgnored() {
        let lb = WorkoutLog(date: "2026-10-27", dayName: "x", dayIndex: 1, unit: .lb, sets: ["Bench": [s("100", "10"), s("", "12")]])
        let lift = Strength.lift("Bench", plan: [], logs: [lb], now, weeks: 1, cal)
        XCTAssertEqual(lift.weeks[0].volume, 453.592, accuracy: 0.01) // 100 lb x 10; the weightless set adds nothing
    }

    func testGroupsAndMinimumSessions() {
        let logs = [
            log("2026-10-13", ["Squat": [s("100", "5")], "Bench press": [s("60", "8")]]),
            log("2026-10-20", ["Squat": [s("105", "5")]]),
            log("2026-10-27", ["Squat": [s("110", "5")]]),
        ]
        let all = Strength.series(plan: [], logs: logs, now, weeks: 4, cal)
        let byFilter = Dictionary(uniqueKeysWithValues: all.map { ($0.filter, $0) })
        XCTAssertEqual(byFilter[.overall]?.sessions, 3)
        XCTAssertEqual(byFilter[.lower]?.enough, true)
        XCTAssertEqual(byFilter[.upper]?.sessions, 1)
        XCTAssertEqual(byFilter[.upper]?.enough, false) // one chest session is too little to draw a line
        XCTAssertNil(byFilter[.muscle(.calves)])        // no calf lifts at all: not offered
        XCTAssertEqual(byFilter[.muscle(.quads)]?.enough, true)
    }

    func testSwappedNamesCountUnderTheNameDone() {
        let l = WorkoutLog(date: "2026-10-27", dayName: "x", dayIndex: 1, sets: ["Squat": [s("60", "10")]], swaps: ["Squat": "Hack squats"])
        let lift = Strength.lift("Hack squats", plan: [], logs: [l], now, weeks: 1, cal)
        XCTAssertEqual(lift.weeks[0].volume, 600, accuracy: 0.001)
        XCTAssertEqual(Strength.lift("Squat", plan: [], logs: [l], now, weeks: 1, cal).sessions, 0)
    }
}
