import XCTest
@testable import Fit2216Core

final class BackupTests: XCTestCase {
    private let valid = #"""
    {"app":"couple-fit","plan":[{"day":1,"name":"Push","type":"strength","exercises":[{"name":"Bench","sets":3,"reps":"4–6","muscles":["chest"]}]}],
     "profile":{"name":"Me","proteinMin":100,"proteinMax":140,"units":"imperial","extraField":"kept"},
     "library":["Bench"],
     "logs":[{"date":"2026-10-14","dayIndex":1,"dayName":"Push","unit":"lb","sets":{"Bench":[{"weight":"100","reps":"6"}]}}],
     "weights":[{"date":"2026-10-14","kg":80}],
     "partnerUid":"never-restored"}
    """#

    func testAValidBackupIsReadAndKeepsProfileFieldsItDoesNotKnow() throws {
        let b = try Backup.parse(valid)
        XCTAssertEqual(b.plan.map(\.name), ["Push"]); XCTAssertEqual(b.library, ["Bench"])
        XCTAssertEqual(b.logs[0].sets["Bench"]?[0].reps, "6"); XCTAssertEqual(b.weights, [WeightEntry(date: "2026-10-14", kg: 80)])
        XCTAssertEqual(b.profile["extraField"] as? String, "kept")
    }

    func testRejectsFilesThatAreNotOursOrAreUnsoundInAnyPart() {
        func rejects(_ s: String) { XCTAssertThrowsError(try Backup.parse(s), s.prefix(80).description) }
        rejects("not json")
        rejects(valid.replacingOccurrences(of: #""app":"couple-fit""#, with: #""app":"other""#))
        rejects(valid.replacingOccurrences(of: #""plan":[{"day":1"#, with: #""plan":[{"day":9"#))              // weekday out of range
        rejects(valid.replacingOccurrences(of: #""date":"2026-10-14","dayIndex""#, with: #""date":"2026-02-30","dayIndex""#)) // impossible date
        rejects(valid.replacingOccurrences(of: #""kg":80"#, with: #""kg":-1"#))
        rejects(valid.replacingOccurrences(of: #""units":"imperial""#, with: #""units":"stone""#))
        rejects(valid.replacingOccurrences(of: #""weight":"100""#, with: #""weight":100"#))                       // a set weight must be text
        rejects(valid.replacingOccurrences(of: #""muscles":["chest"]"#, with: #""muscles":["wings"]"#))
        rejects(valid.replacingOccurrences(of: #""plan":[{"day":1,"name":"Push","type":"strength","exercises":[{"name":"Bench","sets":3,"reps":"4–6","muscles":["chest"]}]}]"#, with: #""plan":[]"#))
    }

    func testDuplicateEntriesAreRejected() {
        let twice = valid.replacingOccurrences(of: #""weights":[{"date":"2026-10-14","kg":80}]"#, with: #""weights":[{"date":"2026-10-14","kg":80},{"date":"2026-10-14","kg":81}]"#)
        XCTAssertThrowsError(try Backup.parse(twice)) { XCTAssertEqual(($0 as? BackupError)?.message, "Duplicate backup entries") }
    }

    func testExportStripsSharingFieldsAndRoundTrips() throws {
        let user: [String: Any] = ["plan": [["day": 1, "name": "Push", "type": "strength", "exercises": [["name": "Bench", "sets": 3, "reps": "5"]]]], "library": ["Bench"],
                                   "profile": ["name": "Me", "proteinMin": 100, "proteinMax": 140], "circle": ["x"], "partnerUid": "y", "pending": ["z"], "macroSync": "w"]
        let logs: [[String: Any]] = [["date": "2026-10-14", "dayIndex": 1, "dayName": "Push", "sets": ["Bench": [["weight": "100", "reps": "6"]]]]]
        let text = try XCTUnwrap(Backup.export(user: user, logs: logs, weights: [["date": "2026-10-14", "kg": 80]], exportedAt: "2026-11-06T00:00:00Z"))
        for gone in ["partnerUid", "circle", "pending", "macroSync"] { XCTAssertFalse(text.contains(gone), gone) }
        let back = try Backup.parse(text)
        XCTAssertEqual(back.logs.count, 1); XCTAssertEqual(back.weights.count, 1); XCTAssertEqual(back.plan[0].exercises[0].name, "Bench")
    }
}
