import XCTest
@testable import Fit2216Core

final class EquipmentTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }

    func testOldPlanHasNoEquipment() throws {
        let e = try decode(TemplateExercise.self, #"{"name":"Bench Press","sets":4,"reps":"8–12"}"#)
        XCTAssertNil(e.equipment)
    }
    func testKnownAndUnknownEquipment() throws {
        XCTAssertEqual(try decode(TemplateExercise.self, #"{"name":"A","sets":3,"reps":"8","equipment":"cable"}"#).equipment, .cable)
        XCTAssertNil(try decode(TemplateExercise.self, #"{"name":"A","sets":3,"reps":"8","equipment":"rocket"}"#).equipment)
        XCTAssertNil(try decode(TemplateExercise.self, #"{"name":"A","sets":3,"reps":"8","equipment":7}"#).equipment)
    }
    func testEquipmentRoundTrips() throws {
        let e = TemplateExercise(name: "Row", sets: 3, reps: "8", equipment: .dumbbell)
        let back = try decode(TemplateExercise.self, String(decoding: try JSONEncoder().encode(e), as: UTF8.self))
        XCTAssertEqual(back.equipment, .dumbbell)
        XCTAssertEqual(back, e)
    }
    func testSessionIdRoundTripsAndIsOptional() throws {
        let old = try decode(WorkoutLog.self, #"{"date":"2026-11-07","dayName":"Legs B","sets":{}}"#)
        XCTAssertNil(old.sessionId)
        let blank = try decode(WorkoutLog.self, #"{"date":"2026-11-07","dayName":"Legs B","sessionId":"","sets":{}}"#)
        XCTAssertNil(blank.sessionId)
        var log = WorkoutLog(date: "2026-11-07", dayName: "Legs B", sessionId: "6F1C2B9E-4D7A-4C1E-9B2A-0D3E5F7A8B91")
        let back = try decode(WorkoutLog.self, String(decoding: try JSONEncoder().encode(log), as: UTF8.self))
        XCTAssertEqual(back.sessionId, log.sessionId)
        log.sessionId = nil
        XCTAssertNil(log.sessionId)
    }
    func testGuessFromName() {
        XCTAssertEqual(Equipment.guess(from: "Flat barbell bench press"), .barbell)
        XCTAssertEqual(Equipment.guess(from: "Dumbbell biceps curls"), .dumbbell)
        XCTAssertEqual(Equipment.guess(from: "Cable Fly (H2L)"), .cable)
        XCTAssertEqual(Equipment.guess(from: "Machine lateral raises"), .machine)
        XCTAssertEqual(Equipment.guess(from: "Leg press"), .machine)
        XCTAssertEqual(Equipment.guess(from: "Smith squat"), .smith)
        XCTAssertEqual(Equipment.guess(from: "Pull-ups"), .bodyweight)
        XCTAssertNil(Equipment.guess(from: "Bench Press"))
        XCTAssertNil(Equipment.guess(from: "Shoulder press"))
    }
}
