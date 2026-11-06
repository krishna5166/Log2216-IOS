import XCTest
@testable import Fit2216Core

final class UserDocTests: XCTestCase {
    func testAWebAppUserDocumentIsRead() throws {
        let json = #"""
        {"plan":[{"day":1,"name":"Legs A","type":"strength","exercises":[{"name":"Barbell squats","sets":4,"reps":"4–6","muscles":["quads","wings"]}]},
                 {"day":6,"name":"Rest","type":"rest","exercises":[]}],
         "library":["Plank"],
         "profile":{"name":"Mohan","units":"imperial","gymUnit":"lb","bodyUnit":"kg","heightCm":175,"targetWeightKg":70,"goal":"lose","proteinMin":145,"proteinMax":180,"targets":{"kcal":2200}},
         "circle":["abc"],"macroSync":null}
        """#
        let doc = try decode(UserDoc.self, json)
        XCTAssertEqual(doc.plan.map(\.name), ["Legs A", "Rest"])
        XCTAssertEqual(doc.plan[0].exercises[0].muscles, [.quads])
        XCTAssertEqual(doc.library, ["Plank"])
        XCTAssertEqual(doc.profile.name, "Mohan")
        XCTAssertEqual(doc.profile.gymUnit, .lb); XCTAssertEqual(doc.profile.bodyUnit, .kg)
        XCTAssertEqual(doc.profile.goal, .lose); XCTAssertEqual(doc.profile.targetWeightKg, 70)
    }

    func testOlderProfilesFollowTheUnitSystem() throws {
        XCTAssertEqual(try decode(UserDoc.self, #"{"profile":{"name":"A","units":"imperial"}}"#).profile.gymUnit, .lb)
        XCTAssertEqual(try decode(UserDoc.self, #"{"profile":{"name":"A","units":"imperial","bodyUnit":"kg"}}"#).profile.bodyUnit, .kg)
        XCTAssertEqual(try decode(UserDoc.self, #"{"profile":{"name":"A"}}"#).profile.gymUnit, .kg)
    }

    func testBrokenDocumentsBecomeEmptyOnesInsteadOfFailing() throws {
        let doc = try decode(UserDoc.self, #"{"plan":[null,{"day":2,"name":"Pull","exercises":null},{"name":"no day"}],"library":"x","profile":null}"#)
        XCTAssertEqual(doc.plan.map(\.day), [2]); XCTAssertEqual(doc.plan[0].exercises, [])
        XCTAssertEqual(doc.library, []); XCTAssertEqual(doc.profile.name, "")
        XCTAssertEqual(try decode(UserDoc.self, "{}"), UserDoc())
        XCTAssertEqual(try decode(UserDoc.self, #"{"plan":"nope"}"#).plan, [])
    }

    func testFirestoreStyleDictionariesAreDecoded() {
        let object: [String: Any] = ["date": "2026-10-27", "dayName": "Legs", "dayIndex": 3, "done": true, "unit": "lb", "sets": ["Squat": [["weight": "100", "reps": "5"], NSNull()]]]
        let log = FirestoreDecoding.decode(WorkoutLog.self, from: object)
        XCTAssertEqual(log?.sets["Squat"]?.count, 2); XCTAssertEqual(log?.done, true); XCTAssertEqual(log?.dayIndex, 3)
        XCTAssertNil(FirestoreDecoding.decode(WorkoutLog.self, from: ["date": Date()])) // not plain JSON values
        XCTAssertNil(FirestoreDecoding.decode(WorkoutLog.self, from: ["dayName": "no date"])) // a log needs its date
    }
}
