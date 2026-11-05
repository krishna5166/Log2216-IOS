import XCTest
@testable import CoupleFitCore

final class MusclesTests: XCTestCase {
    func testCommonLiftsAndTheOrderingTraps() {
        XCTAssertEqual(Muscles.forName("Incline bench press").primary, [.chest])
        XCTAssertEqual(Muscles.forName("Lying leg curl").primary, [.hamstrings])      // not "curl" (biceps)
        XCTAssertTrue(Muscles.forName("Leg press").primary.contains(.quads))           // not "press" (chest)
        XCTAssertEqual(Muscles.forName("Machine shoulder press").primary, [.shoulders])
        XCTAssertEqual(Muscles.forName("V-bar triceps pushdowns").primary, [.triceps])
        XCTAssertEqual(Muscles.forName("Lat pulldown").primary, [.lats])
        XCTAssertEqual(Muscles.forName("Mystery move").primary, [])
    }

    func testNamesThatUsedToLandOnTheWrongMuscle() {
        XCTAssertEqual(Muscles.forName("Overhead cable triceps extension").primary, [.triceps])
        XCTAssertEqual(Muscles.forName("Chest-supported row").primary, [.lats])
        XCTAssertEqual(Muscles.forName("Torso Rotator Machine").primary, [.obliques])
        XCTAssertEqual(Muscles.forName("Flat barbell bench press").primary, [.chest]) // "Flat" is not "lat"
        XCTAssertEqual(Muscles.forName("Overhead press").primary, [.shoulders])
    }

    func testHips() {
        XCTAssertEqual(Muscles.forName("Hip abductor (outside)").primary, [.glutes])
        XCTAssertEqual(Muscles.forName("Hip adductor (inside)").primary, [.adductors])
        XCTAssertTrue(Muscles.forName("Hip thrust").primary.contains(.glutes))
    }

    func testPrimaryBeatsSecondaryAndTheDayNameIsTheFallback() {
        let push = TemplateDay(day: 1, name: "Push", exercises: [TemplateExercise(name: "Bench press", sets: 3, reps: "8"), TemplateExercise(name: "Triceps rope pushdown", sets: 3, reps: "10")])
        let m = Muscles.forDay(push)
        XCTAssertEqual(m[.chest], .primary); XCTAssertEqual(m[.triceps], .primary); XCTAssertEqual(m[.shoulders], .secondary)
        XCTAssertEqual(Muscles.forDay(TemplateDay(day: 3, name: "Leg day", exercises: [TemplateExercise(name: "Mystery move", sets: 3, reps: "8")]))[.quads], .primary)
    }

    func testChosenMusclesWinOverTheNameGuess() {
        let named = TemplateExercise(name: "Machine 3", sets: 3, reps: "10")
        XCTAssertTrue(Muscles.forDay(TemplateDay(day: 1, name: "Day", exercises: [named])).isEmpty)
        var chosen = named; chosen.muscles = [.chest, .triceps]
        XCTAssertEqual(Muscles.forDay(TemplateDay(day: 1, name: "Day", exercises: [chosen]))[.chest], .primary)
        var empty = TemplateExercise(name: "Bench press", sets: 3, reps: "8"); empty.muscles = []
        XCTAssertEqual(Muscles.forDay(TemplateDay(day: 1, name: "Day", exercises: [empty]))[.chest], .primary)
    }

    func testWhichSideTurnsToward() {
        func side(_ name: String, _ ex: [String]) -> BodySide { Muscles.side(for: Muscles.forDay(TemplateDay(day: 1, name: name, exercises: ex.map { TemplateExercise(name: $0, sets: 3, reps: "8") }))) }
        XCTAssertEqual(side("Pull", ["Barbell row", "Lat pulldown", "Barbell curl"]), .back)
        XCTAssertEqual(side("Push", ["Bench press", "Cable fly"]), .front)
        XCTAssertEqual(side("Nothing", []), .front)
        XCTAssertEqual(side("Legs", ["Barbell squats", "Romanian deadlift", "Hamstring curls", "Standing calf raises"]), .front)
    }
}
