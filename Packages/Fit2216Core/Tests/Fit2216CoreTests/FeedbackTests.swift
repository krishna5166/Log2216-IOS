import XCTest
@testable import Fit2216Core

final class FeedbackTests: XCTestCase {
    private let plan = [
        TemplateDay(day: 2, name: "Chest and Triceps", exercises: [
            TemplateExercise(name: "Bench Press", sets: 4, reps: "8–12", equipment: .barbell),
            TemplateExercise(name: "Cable Fly (H2L)", sets: 3, reps: "8–12"),
        ]),
        TemplateDay(day: 4, name: "Shoulder and Abs", exercises: [
            TemplateExercise(name: "Torso Rotator Machine", sets: 2, reps: "8–12"),
        ]),
    ]
    private func log(_ sets: [String: [SetLog]], swaps: [String: String]? = nil, done: Bool? = true, id: String? = "6F1C2B9E-4D7A") -> WorkoutLog {
        WorkoutLog(date: "2026-11-03", dayName: "Chest and Triceps", dayIndex: 2, unit: .lb, done: done, sets: sets, swaps: swaps, sessionId: id)
    }
    private func make(_ l: WorkoutLog) -> FeedbackSession? {
        FeedbackSession.make(from: l, plan: plan, now: Date(timeIntervalSince1970: 0), timeZone: TimeZone(identifier: "America/Los_Angeles")!)
    }

    func testBuildsSessionFromTextSets() throws {
        let s = try XCTUnwrap(make(log(["Bench Press": [SetLog(weight: "135", reps: "8"), SetLog(weight: "135", reps: "7"), SetLog(weight: "", reps: "")],
                                        "Cable Fly (H2L)": [SetLog(weight: "30", reps: "10")]])))
        XCTAssertEqual(s.sessionId, "6F1C2B9E-4D7A")
        XCTAssertEqual(s.planDay, 2)
        XCTAssertEqual(s.completedAt, "1970-01-01T00:00:00Z")
        XCTAssertEqual(s.sets.filter { $0.exercise == "Bench Press" }.map(\.setIndex), [0, 1])
        XCTAssertEqual(s.sets.first { $0.exercise == "Bench Press" }?.equipment, "barbell")
        XCTAssertEqual(s.sets.first { $0.exercise == "Cable Fly (H2L)" }?.equipment, "cable")   // guessed from the name
        XCTAssertEqual(s.sets.first?.unit, "lb")
        XCTAssertEqual(s.planned.first { $0.exercise == "Bench Press" }, .init(exercise: "Bench Press", equipment: "barbell", sets: 4, reps: "8–12"))
    }
    func testNothingToSend() {
        XCTAssertNil(make(log(["Bench Press": [SetLog(weight: "135", reps: "8")]], done: nil)))             // not finished
        XCTAssertNil(make(log(["Bench Press": [SetLog(weight: "135", reps: "8")]], id: nil)))               // no session id
        XCTAssertNil(make(log(["Bench Press": [SetLog(weight: "", reps: "")]])))                            // no set filled
        var skipped = log(["Bench Press": [SetLog(weight: "135", reps: "8")]]); skipped.skipped = true
        XCTAssertNil(make(skipped))
    }
    func testBadNumbersAreDropped() throws {
        let s = try XCTUnwrap(make(log(["Bench Press": [SetLog(weight: "abc", reps: "8"), SetLog(weight: "99999", reps: "8"), SetLog(weight: "-5", reps: "8"),
                                                       SetLog(weight: "135", reps: "x"), SetLog(weight: "135,5", reps: "6")]])))
        XCTAssertEqual(s.sets.count, 1)
        XCTAssertEqual(s.sets[0].weight, 135.5)
        XCTAssertEqual(s.sets[0].setIndex, 0)
    }
    func testBodyweightIsWeightZero() throws {
        let s = try XCTUnwrap(make(log(["Pull-ups": [SetLog(weight: "", reps: "9")]])))
        XCTAssertEqual(s.sets[0].weight, 0)
        XCTAssertEqual(s.sets[0].equipment, "bodyweight")
    }
    func testSwapIsPostedUnderItsOwnNameAndNotPlanned() throws {
        var l = log(["Torso Rotator Machine": [SetLog(weight: "40", reps: "10")]], swaps: ["Torso Rotator Machine": "Twist"])
        l.dayIndex = 4; l.dayName = "Shoulder and Abs"
        let s = try XCTUnwrap(make(l))
        XCTAssertEqual(s.sets[0].exercise, "Twist")
        XCTAssertTrue(s.planned.isEmpty)
    }
    func testAliasedNameIsPostedAsCurrentName() throws {
        let s = try XCTUnwrap(make(log(["Flat barbell bench press": [SetLog(weight: "135", reps: "8")]])))
        XCTAssertEqual(s.sets[0].exercise, "Bench Press")
        XCTAssertEqual(s.sets[0].equipment, "barbell")   // from the raw name, not the alias
    }

    private func proposal(_ json: String) throws -> PlanProposal { try JSONDecoder().decode(PlanProposal.self, from: Data(json.utf8)) }
    private let body = #"""
    {"planVersion":13,"summary":"Bench press +5 lb","plan":{"exercises":[
      {"exercise":"Bench Press","equipment":"barbell","sets":4,"reps":"8–12","weight":140,"unit":"lb"},
      {"exercise":"Bench Press","equipment":"dumbbell","sets":3,"reps":"8","weight":50,"unit":"lb"},
      {"exercise":"Mystery","equipment":"rocket","sets":3,"reps":"8"},
      {"exercise":"Cable Fly (H2L)","equipment":"cable","sets":3,"reps":"8–12","weight":null}]},
     "changes":[{"day":2,"exercise":"Bench Press","equipment":"barbell","field":"weight","from":135,"to":140,"unit":"lb"}]}
    """#

    func testProposalDecodingDropsBadEntries() throws {
        let p = try proposal(body)
        XCTAssertEqual(p.planVersion, 13)
        XCTAssertEqual(p.exercises.count, 3)   // the "rocket" entry is dropped
        XCTAssertEqual(p.changes.first?.to, "140")
        XCTAssertThrowsError(try proposal(#"{"planVersion":0,"plan":{"exercises":[]}}"#))
        XCTAssertEqual(try proposal(#"{"planVersion":2}"#).exercises, [])
    }
    func testApplyMatchesByNameAndEquipment() throws {
        let (next, changed) = try proposal(body).applied(to: plan)
        XCTAssertEqual(changed, ["Bench Press"])    // the dumbbell series does not touch the barbell exercise; fly has no change
        XCTAssertEqual(next[0].exercises[0].weight, 140)
        XCTAssertEqual(next[0].exercises[0].weightUnit, .lb)
        XCTAssertEqual(next[0].exercises[0].reps, "8–12")
        XCTAssertEqual(next[0].exercises[1], plan[0].exercises[1])
        XCTAssertEqual(next[1], plan[1])
    }
    func testApplyNeverAddsOrRenames() throws {
        let (next, _) = try proposal(body).applied(to: plan)
        XCTAssertEqual(next.map { $0.exercises.map(\.name) }, plan.map { $0.exercises.map(\.name) })
    }
    func testOfferRules() throws {
        let p = try proposal(body)
        XCTAssertTrue(PlanOffer.shouldShow(proposal: p, plan: plan, acceptedVersion: 12, declinedVersion: 0, workoutOpen: false))
        XCTAssertFalse(PlanOffer.shouldShow(proposal: p, plan: plan, acceptedVersion: 13, declinedVersion: 0, workoutOpen: false))   // already accepted
        XCTAssertFalse(PlanOffer.shouldShow(proposal: p, plan: plan, acceptedVersion: 0, declinedVersion: 13, workoutOpen: false))   // declined
        XCTAssertFalse(PlanOffer.shouldShow(proposal: p, plan: plan, acceptedVersion: 0, declinedVersion: 0, workoutOpen: true))     // workout open
        let next = PlanProposal.applied(try proposal(body))(to: plan).plan
        XCTAssertFalse(PlanOffer.shouldShow(proposal: p, plan: next, acceptedVersion: 0, declinedVersion: 0, workoutOpen: false))    // nothing left to change
        let newer = try proposal(body.replacingOccurrences(of: "\"planVersion\":13", with: "\"planVersion\":14"))
        XCTAssertTrue(PlanOffer.shouldShow(proposal: newer, plan: plan, acceptedVersion: 0, declinedVersion: 13, workoutOpen: false))  // a new version asks again
    }
    func testLineFallsBackToCount() throws {
        let p = try proposal(#"{"planVersion":2,"summary":"  "}"#)
        XCTAssertEqual(PlanOffer.line(proposal: p, changedCount: 1), "One exercise has new numbers based on your last sessions")
        XCTAssertEqual(PlanOffer.line(proposal: try proposal(body), changedCount: 3), "Bench press +5 lb")
    }
    func testPlanWeightRoundTripsAndOldPlansDecode() throws {
        let e = TemplateExercise(name: "Row", sets: 3, reps: "8", weight: 62.5, weightUnit: .kg)
        let back = try JSONDecoder().decode(TemplateExercise.self, from: JSONEncoder().encode(e))
        XCTAssertEqual(back, e)
        let old = try JSONDecoder().decode(TemplateExercise.self, from: Data(#"{"name":"Row","sets":3,"reps":"8","weight":-4}"#.utf8))
        XCTAssertNil(old.weight)
    }
}

final class PlanWeightHintTests: XCTestCase {
    private func hint(planWeight: Double?, unit: WeightUnit? = .lb, history: [WorkoutLog] = [], logged: [SetLog] = []) -> SetLog? {
        let ex = TemplateExercise(name: "Bench Press", sets: 4, reps: "8–12", weight: planWeight, weightUnit: unit)
        let log = WorkoutLog(date: "2026-11-10", dayName: "D", dayIndex: 2, unit: .lb, sets: logged.isEmpty ? [:] : ["Bench Press": logged])
        return Logging.suggestion(exercise: ex, shownName: "Bench Press", index: logged.count, log: log, history: history, unit: .lb)
    }
    func testPlanWeightUsedWithNoHistory() {
        XCTAssertEqual(hint(planWeight: 140)?.weight, "140")
    }
    func testLowerPlanWeightDoesNotBeatHistory() {
        let past = WorkoutLog(date: "2026-11-03", dayName: "D", dayIndex: 2, unit: .lb, done: true, sets: ["Bench Press": [SetLog(weight: "150", reps: "8")]])
        XCTAssertEqual(hint(planWeight: 140, history: [past])?.weight, "150")
    }
    func testNotUsedAfterAFirstSetIsLogged() {
        XCTAssertEqual(hint(planWeight: 140, logged: [SetLog(weight: "135", reps: "8")])?.weight, "135")
    }
    func testOtherUnitIgnoredAndNoWeightIsHarmless() {
        XCTAssertNotEqual(hint(planWeight: 60, unit: .kg)?.weight, "60")
        XCTAssertNil(hint(planWeight: nil)?.weight.nonEmpty)
    }
}
private extension String { var nonEmpty: String? { isEmpty ? nil : self } }
