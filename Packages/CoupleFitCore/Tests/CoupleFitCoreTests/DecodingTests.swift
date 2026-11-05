import XCTest
@testable import CoupleFitCore

/// The blank-screen bugs of the web app, as decoding cases: bad data must never stop a screen from drawing.
final class DecodingTests: XCTestCase {
    func testNullSetInsideAListBecomesAnEmptySetAndKeepsItsPosition() throws {
        let log = try decode(WorkoutLog.self, #"{"date":"2026-10-27","dayName":"Legs","dayIndex":3,"sets":{"Squat":[null,{"weight":"100","reps":"5"},{"weight":80,"reps":null}]}}"#)
        XCTAssertEqual(log.sets["Squat"], [SetLog(), SetLog(weight: "100", reps: "5"), SetLog(weight: "80", reps: "")])
    }

    func testSetsNullOrMissingBecomesEmpty() throws {
        for json in [#"{"date":"2026-10-27","dayName":"Push","sets":null}"#, #"{"date":"2026-10-27","dayName":"Push"}"#, #"{"date":"2026-10-27","dayName":"Push","sets":"x"}"#] {
            let log = try decode(WorkoutLog.self, json)
            XCTAssertEqual(log.sets, [:])
            XCTAssertEqual(Plan.loggedSets(log), 0)
        }
    }

    func testAnExerciseListThatIsNullIsEmptyAndUnreadableExercisesAreDropped() throws {
        let day = try decode(TemplateDay.self, #"{"day":1,"name":"Push","type":"strength","exercises":null}"#)
        XCTAssertEqual(day.exercises, [])
        let mixed = try decode(TemplateDay.self, #"{"day":2,"name":"Pull","type":"strength","exercises":[null,{"name":"Row","sets":3,"reps":"8"},{"sets":3},42]}"#)
        XCTAssertEqual(mixed.exercises.map(\.name), ["Row"])
    }

    func testAPlanKeepsReadableDaysAndDropsJunk() throws {
        let plan = try decode(LossyPlan.self, #"[{"day":1,"name":"Push","type":"strength","exercises":null},null,{"name":"no day"},{"day":2,"name":"Pull","type":"strength","exercises":[null,{"name":"Row","sets":3,"reps":"8"}]}]"#)
        XCTAssertEqual(plan.days.map(\.day), [1, 2])
        XCTAssertEqual(plan.days.map { $0.exercises.count }, [0, 1])
    }

    func testATemplateWithNullExercisesInsideALogIsRepaired() throws {
        let log = try decode(WorkoutLog.self, #"{"date":"2026-10-27","dayName":"Push","dayIndex":1,"sets":{},"template":{"day":1,"name":"Push","type":"strength","exercises":null}}"#)
        XCTAssertEqual(log.template?.exercises, [])
    }

    func testNumbersWhereTheAppWritesTextAreAccepted() throws {
        let s = try decode(SetLog.self, #"{"weight":135,"reps":8}"#)
        XCTAssertEqual(s, SetLog(weight: "135", reps: "8"))
        let half = try decode(SetLog.self, #"{"weight":22.5,"reps":"10"}"#)
        XCTAssertEqual(half.weight, "22.5")
    }

    func testUnknownMusclesInAnOverrideAreIgnored() throws {
        let e = try decode(TemplateExercise.self, #"{"name":"Machine 3","sets":3,"reps":"10","muscles":["chest","wings","triceps"]}"#)
        XCTAssertEqual(e.muscles, [.chest, .triceps])
    }

    func testARealWebAppLogRoundTrips() throws {
        let json = #"{"date":"2026-10-14","dayIndex":1,"dayName":"Push","unit":"lb","done":true,"sets":{"Bench":[{"weight":"100","reps":"6"}]},"swaps":{"Press":"Dips"}}"#
        let log = try decode(WorkoutLog.self, json)
        XCTAssertEqual(log.unit, .lb)
        XCTAssertEqual(Plan.effectiveName(log, "Press"), "Dips")
        let again = try decode(WorkoutLog.self, String(data: try JSONEncoder().encode(log), encoding: .utf8)!)
        XCTAssertEqual(again, log)
    }
}

/// Test helper: a plan decoded the way the app will decode one, keeping readable days.
struct LossyPlan: Decodable {
    var days: [TemplateDay]
    init(from decoder: Decoder) throws { days = try LossyArray<TemplateDay>(from: decoder).elements }
}
