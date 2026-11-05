import XCTest
@testable import Fit2216Core

final class InsightsTests: XCTestCase {
    private let now = day(2026, 10, 28) // Wednesday
    private func log(_ date: String, _ dayIndex: Int, _ sets: [String: [SetLog]] = [:], done: Bool? = nil, skipped: Bool? = nil, swaps: [String: String]? = nil) -> WorkoutLog {
        WorkoutLog(date: date, dayName: "x", dayIndex: dayIndex, done: done, skipped: skipped, sets: sets, swaps: swaps)
    }
    private func s(_ w: String, _ r: String) -> SetLog { SetLog(weight: w, reps: r) }
    private func w(_ date: String, _ kg: Double) -> WeightEntry { WeightEntry(date: date, kg: kg) }

    func testEpleyEstimateAndCaps() {
        XCTAssertEqual(Insights.e1rm(weight: 100, reps: 5), 116.67, accuracy: 0.01)
        XCTAssertEqual(Insights.e1rm(weight: 0, reps: 5), 0)
        XCTAssertEqual(Insights.e1rm(weight: 100, reps: 20), 140, accuracy: 0.01) // reps capped at 12
    }

    func testBestSetPerDayAndSwappedNames() {
        let h = Insights.liftHistory([
            log("2026-10-01", 1, ["Squat": [s("100", "5"), s("90", "5")]]),
            log("2026-10-08", 1, ["Squat": [s("60", "10")]], swaps: ["Squat": "Hack squats"]),
        ])
        XCTAssertEqual(h["Squat"]?.count, 1)
        XCTAssertEqual(h["Squat"]?[0].weight, 100)
        XCTAssertEqual(h["Hack squats"]?[0].reps, 10)
    }

    func testLiftHistoryConvertsPoundsToKilograms() {
        let l = WorkoutLog(date: "2026-10-01", dayName: "x", dayIndex: 1, unit: .lb, sets: ["Bench": [s("100", "5")]])
        XCTAssertEqual(Insights.liftHistory([l])["Bench"]?[0].weight ?? 0, 45.359, accuracy: 0.001)
    }

    func testPersonalRecordsOnlyWithinTheWindowAndOnePerLift() {
        let h = Insights.liftHistory([
            log("2026-10-01", 1, ["Bench": [s("80", "5")]]),
            log("2026-10-15", 1, ["Bench": [s("80", "4")]]),
            log("2026-10-27", 1, ["Bench": [s("85", "5")]]),
        ])
        let prs = Insights.recentPRs(h, now, days: 14, limit: 6, cal)
        XCTAssertEqual(prs.count, 1); XCTAssertEqual(prs[0].name, "Bench"); XCTAssertEqual(prs[0].weight, 85)
        XCTAssertEqual(Insights.recentPRs(h, day(2026, 12, 1), days: 14, limit: 6, cal).count, 0)
    }

    func testWeeklyStatsCountFinishedNotSkippedAndSumVolume() {
        let plan = [trainingDay(1, "A"), trainingDay(2, "B")]
        let logs = [
            log("2026-10-26", 1, ["A": [s("50", "10")]], done: true),
            log("2026-10-27", 2, [:], skipped: true),
            log("2026-10-19", 1, ["A": [s("40", "5")]], done: true),
        ]
        let stats = Insights.weeklyStats(logs, plan: plan, now, weeks: 3, cal)
        XCTAssertEqual(stats.map(\.workouts), [0, 1, 1])
        XCTAssertEqual(stats[2].volume, 500); XCTAssertEqual(stats[1].volume, 200)
        XCTAssertEqual(stats[2].start, "2026-10-26")
    }

    func testChartWeeksStartsAtTheEarliestLog() {
        XCTAssertEqual(Insights.chartWeeks([], now, max: 8, cal), 1)
        XCTAssertEqual(Insights.chartWeeks([log("2026-10-27", 2)], now, max: 8, cal), 1)
        XCTAssertEqual(Insights.chartWeeks([log("2026-10-12", 1)], now, max: 8, cal), 3)
        XCTAssertEqual(Insights.chartWeeks([log("2025-01-01", 1)], now, max: 8, cal), 8)
    }

    func testMovingAverageUsesTheTrailingWeek() {
        let avg = Insights.movingAverage([w("2026-10-01", 90), w("2026-10-02", 92), w("2026-10-12", 91)], days: 7, cal)
        XCTAssertEqual(avg[1].kg, 91); XCTAssertEqual(avg[2].kg, 91)
    }

    func testTrendNeedsEnoughDataThenMeasuresKgPerWeek() {
        XCTAssertNil(Insights.weightTrend([w("2026-10-26", 90), w("2026-10-27", 90.1)], now, cal))
        let entries = [w("2026-10-07", 90), w("2026-10-14", 90.5), w("2026-10-21", 91), w("2026-10-28", 91.5)]
        XCTAssertEqual(Insights.weightTrend(entries, now, cal)!.perWeek, 0.5, accuracy: 0.01)
    }

    func testWeekCountsAndHighlight() {
        let plan = (1...6).map { trainingDay($0, "D\($0)") }
        let nowW = day(2026, 10, 14)
        let c = Insights.weekCounts(plan, [log("2026-10-12", 1, done: true), log("2026-10-13", 2, done: true), log("2026-10-05", 3, done: true)], nowW, cal)
        XCTAssertEqual(c.done, 2); XCTAssertEqual(c.planned, 6)
        let logs = [
            log("2026-09-30", 1, ["Bench": [s("80", "5")], "Row": [s("60", "8")]], done: true),
            log("2026-10-12", 1, ["Bench": [s("85", "5")], "Row": [s("60", "8")], "Curl": [s("20", "10")]], done: true),
        ]
        let h = Insights.liftHighlight(logs, nowW, cal)
        XCTAssertEqual(h?.lift, "Bench"); XCTAssertEqual(h?.gainKg ?? 0, 5 * (1 + 5.0 / 30), accuracy: 0.01); XCTAssertEqual(h?.since, "2026-09-30")
        XCTAssertNil(Insights.liftHighlight(Array(logs.dropFirst()), nowW, cal))
    }

    // MARK: baseline

    private func pt(_ t: Double, _ v: Double) -> BaselineSegment.Point { .init(t: t, v: v) }

    func testSplitByBaseline() {
        XCTAssertEqual(Insights.splitByBaseline([pt(0, 80), pt(10, 79), pt(20, 78)], baseline: 70).count, 1)
        let s = Insights.splitByBaseline([pt(0, 74), pt(10, 66), pt(20, 62)], baseline: 70)
        XCTAssertEqual(s.map(\.above), [true, false])
        XCTAssertEqual(s[0].pts.last, pt(5, 70)); XCTAssertEqual(s[1].pts.first, pt(5, 70))
        XCTAssertEqual(s[1].pts.map(\.t), [5, 10, 20])
        XCTAssertEqual(Insights.splitByBaseline([pt(0, 72), pt(10, 68), pt(20, 72)], baseline: 70).map(\.above), [true, false, true])
        XCTAssertEqual(Insights.splitByBaseline([pt(0, 70)], baseline: 70).map(\.above), [true])
        XCTAssertEqual(Insights.splitByBaseline([], baseline: 70), [])
    }

    func testTones() {
        XCTAssertEqual(Insights.baselineTone(above: true, goal: .lose), .bad)
        XCTAssertEqual(Insights.baselineTone(above: false, goal: .lose), .good)
        XCTAssertEqual(Insights.baselineTone(above: true, goal: .gain), .good)
        XCTAssertEqual(Insights.baselineTone(above: true, goal: nil), .bad)
    }

    func testProjection() {
        XCTAssertEqual(Insights.projectToBaseline(currentKg: 70.2, perWeekKg: -0.5, baselineKg: 70, now, cal).state, .reached)
        XCTAssertEqual(Insights.projectToBaseline(currentKg: 80, perWeekKg: -0.01, baselineKg: 70, now, cal).state, .flat)
        XCTAssertEqual(Insights.projectToBaseline(currentKg: 80, perWeekKg: 0.4, baselineKg: 70, now, cal).state, .away)
        XCTAssertEqual(Insights.projectToBaseline(currentKg: 80, perWeekKg: -0.05, baselineKg: 70, now, cal).state, .far)
        let on = Insights.projectToBaseline(currentKg: 80, perWeekKg: -1, baselineKg: 70, now, cal) // 10 weeks = 70 days after Wed 28 Oct
        XCTAssertEqual(on.state, .on); XCTAssertEqual(on.weeks ?? 0, 10, accuracy: 0.001)
        XCTAssertEqual(Dates.localDate(on.arrival!, cal), "2027-01-06")
    }

    func testRequiredPaceAndBaselineWeight() {
        let p = Insights.requiredPace(currentKg: 80, targetKg: 70, targetDate: "2026-12-23", now, cal)! // 56 days = 8 weeks
        XCTAssertEqual(p.days, 56); XCTAssertEqual(p.perWeekKg, -1.25, accuracy: 0.001)
        XCTAssertNil(Insights.requiredPace(currentKg: 80, targetKg: 70, targetDate: "2026-10-28", now, cal))
        XCTAssertNil(Insights.requiredPace(currentKg: 80, targetKg: 70, targetDate: "2026-10-01", now, cal))
        XCTAssertEqual(Insights.baselineWeight(heightCm: 175, targetWeightKg: 70)?.source, "target")
        XCTAssertEqual(Insights.baselineWeight(heightCm: 175, targetWeightKg: nil)?.kg, 68.9)
        XCTAssertNil(Insights.baselineWeight(heightCm: nil, targetWeightKg: nil))
        XCTAssertNil(Insights.baselineWeight(heightCm: 50, targetWeightKg: 0))
    }
}
