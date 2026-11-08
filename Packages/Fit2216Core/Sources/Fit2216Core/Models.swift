import Foundation

public enum WeightUnit: String, Codable, Equatable, Sendable { case kg, lb }
public enum DayType: String, Codable, Equatable, Sendable { case strength, hypertrophy, rest }

/// One set as typed: weight and reps are text, exactly as in the web app's documents (an empty string means "not entered").
public struct SetLog: Codable, Equatable, Sendable {
    public var weight: String
    public var reps: String
    public init(weight: String = "", reps: String = "") { self.weight = weight; self.reps = reps }

    private enum Keys: String, CodingKey { case weight, reps }
    /// Never throws: a null set, a missing field or a number instead of text becomes a readable (possibly empty) set.
    public init(from decoder: Decoder) throws {
        let c = try? decoder.container(keyedBy: Keys.self)
        weight = c?.lenientString(.weight) ?? ""
        reps = c?.lenientString(.reps) ?? ""
    }
}

public struct TemplateExercise: Codable, Equatable, Sendable {
    public var name: String
    public var sets: Int
    public var reps: String
    public var optional: Bool?
    public var alternatives: [String]?
    public var restSec: Int?
    public var muscles: [Muscle]?
    /// What the exercise is done with. Nil on older plans; an unknown value is ignored rather than failing the plan.
    public var equipment: Equipment?
    /// The weight the plan suggests for this exercise (set when the owner accepts a feedback-loop proposal); nil on older plans.
    public var weight: Double?
    public var weightUnit: WeightUnit?

    public init(name: String, sets: Int, reps: String, optional: Bool? = nil, alternatives: [String]? = nil, restSec: Int? = nil, muscles: [Muscle]? = nil, equipment: Equipment? = nil,
                weight: Double? = nil, weightUnit: WeightUnit? = nil) {
        self.name = name; self.sets = sets; self.reps = reps; self.optional = optional
        self.alternatives = alternatives; self.restSec = restSec; self.muscles = muscles; self.equipment = equipment
        self.weight = weight; self.weightUnit = weightUnit
    }

    private enum Keys: String, CodingKey { case name, sets, reps, optional, alternatives, restSec, muscles, equipment, weight, weightUnit }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        name = try c.decode(String.self, forKey: .name) // an exercise with no name is dropped by its list
        sets = min(100, max(1, c.lenientInt(.sets) ?? 3)) // a plan with 0 or negative sets would break the screens
        reps = c.lenientString(.reps) ?? ""
        optional = c.lenientBool(.optional)
        alternatives = try? c.decodeIfPresent([String].self, forKey: .alternatives)
        restSec = c.lenientInt(.restSec)
        let names = try? c.decodeIfPresent([String].self, forKey: .muscles)
        muscles = names.map { $0.compactMap(Muscle.init(rawValue:)) }
        equipment = c.lenientString(.equipment).flatMap(Equipment.init(rawValue:))
        weight = c.lenientDouble(.weight).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        weightUnit = (try? c.decodeIfPresent(WeightUnit.self, forKey: .weightUnit)) ?? nil
    }
}

public struct TemplateDay: Codable, Equatable, Sendable {
    public var day: Int // 0 = Sunday ... 6 = Saturday
    public var name: String
    public var type: DayType
    public var notes: String?
    public var exercises: [TemplateExercise]

    public init(day: Int, name: String, type: DayType = .strength, notes: String? = nil, exercises: [TemplateExercise] = []) {
        self.day = day; self.name = name; self.type = type; self.notes = notes; self.exercises = exercises
    }

    private enum Keys: String, CodingKey { case day, name, type, notes, exercises }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        let weekday = try c.decode(Int.self, forKey: .day)
        guard (0...6).contains(weekday) else { throw DecodingError.dataCorruptedError(forKey: .day, in: c, debugDescription: "weekday out of range") } // dropped by its list
        day = weekday
        name = c.lenientString(.name) ?? ""
        type = (try? c.decodeIfPresent(DayType.self, forKey: .type)) ?? .strength
        notes = c.lenientString(.notes)
        exercises = (try? c.decodeIfPresent(LossyArray<TemplateExercise>.self, forKey: .exercises))?.elements ?? []
    }
}

public struct WorkoutLog: Codable, Equatable, Sendable {
    public var date: String // YYYY-MM-DD (local)
    public var dayName: String
    public var dayIndex: Int?
    public var unit: WeightUnit?
    public var done: Bool?
    public var skipped: Bool?
    public var sets: [String: [SetLog]]
    public var template: TemplateDay?
    public var swaps: [String: String]?
    /// A UUID made once when the workout is finished and kept for every retry of sending it; nil on workouts finished before it existed.
    public var sessionId: String?

    public init(date: String, dayName: String, dayIndex: Int? = nil, unit: WeightUnit? = nil, done: Bool? = nil, skipped: Bool? = nil,
                sets: [String: [SetLog]] = [:], template: TemplateDay? = nil, swaps: [String: String]? = nil, sessionId: String? = nil) {
        self.date = date; self.dayName = dayName; self.dayIndex = dayIndex; self.unit = unit; self.done = done
        self.skipped = skipped; self.sets = sets; self.template = template; self.swaps = swaps; self.sessionId = sessionId
    }

    private enum Keys: String, CodingKey { case date, dayName, dayIndex, unit, done, skipped, sets, template, swaps, sessionId }
    /// Repairs while reading: `sets` null or missing becomes empty, a null or unreadable set becomes an empty set, a template with no exercises list becomes empty.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        date = try c.decode(String.self, forKey: .date)
        dayName = c.lenientString(.dayName) ?? ""
        dayIndex = c.lenientInt(.dayIndex).flatMap { (0...6).contains($0) ? $0 : nil }
        unit = try? c.decodeIfPresent(WeightUnit.self, forKey: .unit)
        done = c.lenientBool(.done)
        skipped = c.lenientBool(.skipped)
        let raw = (try? c.decodeIfPresent([String: LossySets].self, forKey: .sets)) ?? [:]
        sets = raw.mapValues(\.rows)
        template = try? c.decodeIfPresent(TemplateDay.self, forKey: .template)
        swaps = try? c.decodeIfPresent([String: String].self, forKey: .swaps)
        sessionId = c.lenientString(.sessionId).flatMap { $0.isEmpty ? nil : $0 }
    }

    private struct LossySets: Decodable {
        var rows: [SetLog]
        init(from decoder: Decoder) throws { rows = (try? LossyRows(from: decoder).rows) ?? [] }
    }
    /// Keeps every position (a null set stays as an empty set so set numbers do not shift).
    private struct LossyRows: Decodable {
        var rows: [SetLog] = []
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            while !container.isAtEnd && rows.count < 5000 {
                if let set = try? container.decode(SetLog.self) { rows.append(set) } else { _ = try? container.decode(Skip.self); rows.append(SetLog()) }
            }
        }
    }
}

public struct WeightEntry: Codable, Equatable, Sendable {
    public var date: String
    public var kg: Double
    public init(date: String, kg: Double) { self.date = date; self.kg = kg }
}
