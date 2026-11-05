import Foundation
@testable import CoupleFitCore

/// A fixed calendar so tests behave the same on any machine and any day.
let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "America/Los_Angeles")!; return c }()
func day(_ y: Int, _ m: Int, _ d: Int) -> Date { Dates.date(y, m, d, hour: 12, cal) }

func trainingDay(_ weekday: Int, _ name: String, sets: Int = 2) -> TemplateDay {
    TemplateDay(day: weekday, name: name, type: .strength, exercises: [TemplateExercise(name: "\(name) lift", sets: sets, reps: "8")])
}
func restDay(_ weekday: Int) -> TemplateDay { TemplateDay(day: weekday, name: "Rest", type: .rest) }
func doneLog(_ date: String, _ weekday: Int, _ name: String) -> WorkoutLog { WorkoutLog(date: date, dayName: name, dayIndex: weekday, done: true) }
func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T { try JSONDecoder().decode(type, from: Data(json.utf8)) }
