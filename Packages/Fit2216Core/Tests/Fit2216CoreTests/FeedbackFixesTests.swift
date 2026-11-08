import XCTest
@testable import Fit2216Core

/// Fixes after Grok's 2026-11-08 audit of the feedback loop (synthetic data).
final class FeedbackFixesTests: XCTestCase {
    private let plan = [TemplateDay(day: 2, name: "Chest", exercises: [
        TemplateExercise(name: "Bench Press", sets: 4, reps: "8–12", equipment: .barbell),
        TemplateExercise(name: "Cable Fly", sets: 3, reps: "10–15"),
    ])]
    private func proposal(_ json: String) throws -> PlanProposal { try JSONDecoder().decode(PlanProposal.self, from: Data(json.utf8)) }
    private let body = #"""
    {"planVersion":3,"plan":{"exercises":[
      {"exercise":"Bench Press","equipment":"barbell","sets":5,"reps":"3","weight":140,"unit":"lb"},
      {"exercise":"Cable Fly","equipment":"cable","sets":3,"reps":"10–15","weight":30,"unit":"lb"}]},
     "changes":[{"exercise":"Bench Press","equipment":"barbell","field":"weight","from":null,"to":140,"unit":"lb"}]}
    """#

    func testAcceptAppliesWeightOnlyNeverSetsOrReps() throws {
        let next = try proposal(body).applied(to: plan).plan
        XCTAssertEqual(next[0].exercises[0].weight, 140)
        XCTAssertEqual(next[0].exercises[0].sets, 4)
        XCTAssertEqual(next[0].exercises[0].reps, "8–12")
    }

    func testManualEditSinceTheProposalWasShownWins() throws {
        let shown = plan
        var edited = plan
        edited[0].exercises[0].reps = "5"          // owner edited bench after seeing the line
        let (next, changed) = try proposal(body).applied(to: edited, basis: shown)
        XCTAssertEqual(next[0].exercises[0], edited[0].exercises[0])   // untouched
        XCTAssertEqual(changed, ["Cable Fly"])                          // the unedited exercise still updates
        XCTAssertEqual(next[0].exercises[1].weight, 30)
    }

    func testUnchangedPlanAcceptsEverything() throws {
        XCTAssertEqual(try proposal(body).applied(to: plan, basis: plan).changed, ["Bench Press", "Cable Fly"])
    }

    func testOtherUnitIsNotApplied() throws {
        var kgPlan = plan
        kgPlan[0].exercises[0].weight = 60; kgPlan[0].exercises[0].weightUnit = .kg
        XCTAssertEqual(try proposal(body).applied(to: kgPlan).plan[0].exercises[0].weight, 60)
    }

    private func log(_ sets: [String: [SetLog]], unit: WeightUnit?, reps: String = "8–12") -> WorkoutLog {
        let day = TemplateDay(day: 2, name: "Chest", exercises: [TemplateExercise(name: "Bench Press", sets: 2, reps: reps, equipment: .barbell)])
        return WorkoutLog(date: "2026-11-07", dayName: "Chest", dayIndex: 2, unit: unit, done: true, sets: sets, template: day, sessionId: "SESSION-0001")
    }

    func testSetNumbersAreCaseInsensitiveLikeTheServer() throws {
        let s = try XCTUnwrap(FeedbackSession.make(from: log(["Cable fly": [SetLog(weight: "20", reps: "12")], "cable fly": [SetLog(weight: "20", reps: "12")]], unit: .kg), plan: []))
        let fly = s.sets.filter { $0.exercise.lowercased() == "cable fly" }
        XCTAssertEqual(fly.map(\.setIndex).sorted(), [0, 1])
    }

    func testLogWithoutUnitIsKg() throws {
        let s = try XCTUnwrap(FeedbackSession.make(from: log(["Bench Press": [SetLog(weight: "60", reps: "8")]], unit: nil), plan: []))
        XCTAssertEqual(s.sets[0].unit, "kg")
    }

    func testRepsTextOverTheServerLimitIsLeftOutNotCut() throws {
        let long = String(repeating: "8–12 slow ", count: 25)   // 250 characters
        let s = try XCTUnwrap(FeedbackSession.make(from: log(["Bench Press": [SetLog(weight: "60", reps: "8")]], unit: .kg, reps: long), plan: []))
        XCTAssertTrue(s.planned.isEmpty)
        let ok = String(repeating: "x", count: 150)
        XCTAssertEqual(try XCTUnwrap(FeedbackSession.make(from: log(["Bench Press": [SetLog(weight: "60", reps: "8")]], unit: .kg, reps: ok), plan: [])).planned.first?.reps, ok)
    }

    func testRefusedUploadsAreKeptWithAShortReason() throws {
        let s = try XCTUnwrap(FeedbackSession.make(from: log(["Bench Press": [SetLog(weight: "60", reps: "8")]], unit: .kg), plan: []))
        XCTAssertTrue(FeedbackFailure.isRefusal(400)); XCTAssertTrue(FeedbackFailure.isRefusal(409)); XCTAssertFalse(FeedbackFailure.isRefusal(503))
        XCTAssertEqual(FeedbackFailure.message(status: 400, body: Data(#"{"error":"Bad request","detail":"planned 0: bad entry"}"#.utf8)), "Bad request: planned 0: bad entry")
        XCTAssertEqual(FeedbackFailure.message(status: 413, body: Data("<html>".utf8)), "The server refused this workout (HTTP 413)")
        let a = FeedbackFailure(session: s, status: 400, message: "x", at: "t1")
        let b = FeedbackFailure(session: s, status: 400, message: "y", at: "t2")
        XCTAssertEqual(FeedbackFailure.recording(b, in: [a]), [b])            // one entry per workout
        XCTAssertNil(FeedbackFailure.retryBody(FeedbackFailure(session: s, status: 409, message: "", at: ""), rebuilt: s))   // 409 cannot be retried
        var fixed = s; fixed.sets[0].weight = 62.5
        XCTAssertEqual(FeedbackFailure.retryBody(a, rebuilt: fixed), fixed)   // a corrected log is what gets sent
        XCTAssertEqual(FeedbackFailure.retryBody(a, rebuilt: nil), s)
        let round = try JSONDecoder().decode([FeedbackFailure].self, from: JSONEncoder().encode([a]))
        XCTAssertEqual(round, [a])
    }
}
