import Foundation

/// The workout feedback loop, phone side (wire format: `docs/API_CONTRACT.md` in `log2216-api`, still a draft).
/// Everything here is plain data in, plain data out; sending and showing it is the app's job.

/// One finished workout, in the shape `POST /api/sessions` takes.
public struct FeedbackSession: Codable, Equatable, Sendable {
    public struct Set: Codable, Equatable, Sendable {
        public var exercise: String
        public var equipment: String
        public var setIndex: Int
        public var weight: Double
        public var unit: String
        public var reps: Int
    }
    public struct Planned: Codable, Equatable, Sendable {
        public var exercise: String
        public var equipment: String
        public var sets: Int
        public var reps: String
    }
    public var sessionId: String
    public var date: String
    public var timeZone: String
    public var completedAt: String
    public var planDay: Int?
    public var sets: [Set]
    public var planned: [Planned]

    static let maxSets = 200

    /// What to send for a finished workout, or nil when there is nothing to send: not finished, skipped, no session id yet,
    /// or no usable set. Unfilled and non-numeric sets are left out; a swapped-in lift is posted under its own name and is
    /// not listed in `planned` (the server then only holds, never raises, its weight).
    public static func make(from log: WorkoutLog, plan: [TemplateDay], fallbackUnit: WeightUnit = .lb, now: Date = Date(), timeZone: TimeZone = .current) -> FeedbackSession? {
        guard log.done == true, log.skipped != true, let id = log.sessionId, id.count >= 8 else { return nil }
        let unit = log.unit ?? fallbackUnit
        let day = log.template ?? plan.first { Plan.matches(log, $0) }
        var rows: [Set] = [], planned: [Planned] = []
        var next: [String: Int] = [:]   // exercise + equipment -> next set index
        for original in log.sets.keys.sorted() {
            let swapped = log.swaps?[original].flatMap { $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0 }
            let used = ExerciseNames.canonical(swapped ?? original)
            guard !used.isEmpty else { continue }
            let entry = day?.exercises.first { ExerciseNames.tidy($0.name) == ExerciseNames.tidy(original) }
            let equipment = (swapped == nil ? entry?.equipment : nil) ?? Equipment.guess(from: swapped ?? original) ?? .other
            let key = used + "|" + equipment.rawValue
            var kept = 0
            for set in log.sets[original] ?? [] where Plan.filled(set) {
                guard let reps = Int(set.reps.trimmingCharacters(in: .whitespaces)), reps >= 0 else { continue }
                let w = set.weight.trimmingCharacters(in: .whitespaces)
                let weight = w.isEmpty ? 0 : (Double(w.replacingOccurrences(of: ",", with: ".")) ?? -1)
                guard weight >= 0, weight.isFinite, weight <= (unit == .kg ? 1100 : 2500) else { continue }
                let index = next[key, default: 0]
                next[key] = index + 1
                rows.append(Set(exercise: String(used.prefix(100)), equipment: equipment.rawValue, setIndex: index, weight: weight, unit: unit.rawValue, reps: reps))
                kept += 1
            }
            if kept > 0, swapped == nil, let entry, !entry.reps.isEmpty {
                planned.append(Planned(exercise: String(used.prefix(100)), equipment: equipment.rawValue, sets: entry.sets, reps: entry.reps))
            }
        }
        guard !rows.isEmpty, rows.count <= maxSets else { return nil }
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(identifier: "UTC")
        return FeedbackSession(sessionId: id, date: log.date, timeZone: timeZone.identifier, completedAt: iso.string(from: now),
                               planDay: log.dayIndex ?? day?.day, sets: rows, planned: planned)
    }
}

/// The proposed plan numbers from `GET /api/plan`. Never trusted blindly: bad entries are dropped while reading.
public struct PlanProposal: Decodable, Equatable, Sendable {
    public struct Entry: Decodable, Equatable, Sendable {
        public var exercise: String
        public var equipment: Equipment
        public var sets: Int
        public var reps: String
        public var weight: Double?
        public var unit: WeightUnit?

        private enum Keys: String, CodingKey { case exercise, equipment, sets, reps, weight, unit }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            exercise = try c.decode(String.self, forKey: .exercise)
            guard let e = c.lenientString(.equipment).flatMap(Equipment.init(rawValue:)) else {
                throw DecodingError.dataCorruptedError(forKey: .equipment, in: c, debugDescription: "unknown equipment")
            }
            equipment = e
            guard let s = c.lenientInt(.sets), (1...100).contains(s) else {
                throw DecodingError.dataCorruptedError(forKey: .sets, in: c, debugDescription: "bad sets")
            }
            sets = s
            reps = c.lenientString(.reps) ?? ""
            weight = c.lenientDouble(.weight).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
            unit = (try? c.decodeIfPresent(WeightUnit.self, forKey: .unit)) ?? nil
        }
    }
    public struct Change: Decodable, Equatable, Sendable {
        public var exercise: String
        public var field: String
        public var from: String
        public var to: String
        private enum Keys: String, CodingKey { case exercise, field, from, to }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            exercise = try c.decode(String.self, forKey: .exercise)
            field = c.lenientString(.field) ?? ""
            from = c.lenientString(.from) ?? ""
            to = c.lenientString(.to) ?? ""
        }
    }

    public var planVersion: Int
    public var summary: String?
    public var exercises: [Entry]
    public var changes: [Change]

    private enum Keys: String, CodingKey { case planVersion, summary, plan, changes }
    private enum PlanKeys: String, CodingKey { case exercises }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        guard let v = c.lenientInt(.planVersion), v >= 1 else {
            throw DecodingError.dataCorruptedError(forKey: .planVersion, in: c, debugDescription: "bad version")
        }
        planVersion = v
        summary = c.lenientString(.summary).map { String($0.prefix(200)) }
        let p = try? c.nestedContainer(keyedBy: PlanKeys.self, forKey: .plan)
        exercises = (try? p?.decodeIfPresent(LossyArray<Entry>.self, forKey: .exercises))?.elements ?? []
        changes = (try? c.decodeIfPresent(LossyArray<Change>.self, forKey: .changes))?.elements ?? []
    }

    /// The plan with this proposal's numbers put in, and which exercises actually changed. Entries are matched to plan exercises
    /// by name and equipment (an exercise with no equipment chosen uses the guess from its name, else "other"); an entry that
    /// matches nothing is ignored. Never adds, removes or renames an exercise.
    public func applied(to plan: [TemplateDay]) -> (plan: [TemplateDay], changed: [String]) {
        var out = plan
        var changed: [String] = []
        for d in out.indices {
            for e in out[d].exercises.indices {
                let ex = out[d].exercises[e]
                let equipment = ex.equipment ?? Equipment.guess(from: ex.name) ?? .other
                guard let entry = exercises.first(where: { ExerciseNames.canonical($0.exercise).lowercased() == ExerciseNames.canonical(ex.name).lowercased() && $0.equipment == equipment }) else { continue }
                var next = ex
                next.sets = entry.sets
                if !entry.reps.isEmpty { next.reps = entry.reps }
                if let w = entry.weight { next.weight = w; next.weightUnit = entry.unit ?? ex.weightUnit }
                if next != ex { out[d].exercises[e] = next; changed.append(ex.name) }
            }
        }
        return (out, changed)
    }
}

/// When the Yes / No line is shown. Nothing changes without Yes.
public enum PlanOffer {
    /// Show the line only for a newer version than the one already accepted, that was not declined, that changes at least one
    /// exercise, and never while a workout is open.
    public static func shouldShow(proposal: PlanProposal, plan: [TemplateDay], acceptedVersion: Int, declinedVersion: Int, workoutOpen: Bool) -> Bool {
        guard !workoutOpen, proposal.planVersion > acceptedVersion, proposal.planVersion > declinedVersion else { return false }
        return !proposal.applied(to: plan).changed.isEmpty
    }

    /// The line shown on top: the server's summary, or a plain one from the changes.
    public static func line(proposal: PlanProposal, changedCount: Int) -> String {
        if let s = proposal.summary?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
        return changedCount == 1 ? "One exercise has new numbers based on your last sessions" : "\(changedCount) exercises have new numbers based on your last sessions"
    }
}
