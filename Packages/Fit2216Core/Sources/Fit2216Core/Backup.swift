import Foundation

public struct BackupError: Error, Equatable, CustomStringConvertible {
    public var message: String
    public var description: String { message }
}

/// A validated backup file. Reading is all-or-nothing: nothing is returned unless the whole file is sound. The same file format as the web app.
public struct BackupFile {
    public var plan: [TemplateDay]
    public var library: [String]
    public var profile: [String: Any]       // kept as written, so fields this app does not know are not lost
    public var templates: [Any]?
    public var logs: [WorkoutLog]
    public var weights: [WeightEntry]
}

public enum Backup {
    private static let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()

    private static func validDate(_ v: JSONValue?) -> Bool { v?.string.map { Dates.parse($0, utc) != nil } ?? false }
    private static func weekday(_ v: JSONValue?) -> Bool { v?.number.map { $0 == $0.rounded() && $0 >= 0 && $0 <= 6 } ?? false }
    /// Absent is fine; present must pass `check`.
    private static func optional(_ v: JSONValue?, _ check: (JSONValue) -> Bool) -> Bool { v == nil || check(v!) }

    private static func exercise(_ v: JSONValue) -> Bool {
        guard let name = v["name"]?.string, !name.trimmingCharacters(in: .whitespaces).isEmpty,
              let sets = v["sets"]?.number, sets == sets.rounded(), sets > 0, sets <= 100, v["reps"]?.string != nil else { return false }
        return optional(v["restSec"]) { ($0.number ?? 0) > 0 }
            && optional(v["optional"]) { $0.bool != nil }
            && optional(v["alternatives"]) { $0.array?.allSatisfy { $0.string != nil } ?? false }
            && optional(v["muscles"]) { $0.array?.allSatisfy { m in m.string.flatMap(Muscle.init(rawValue:)) != nil } ?? false }
    }

    private static func day(_ v: JSONValue) -> Bool {
        guard v.object != nil, weekday(v["day"]), v["name"]?.string != nil, let type = v["type"]?.string, DayType(rawValue: type) != nil,
              let exercises = v["exercises"]?.array, exercises.allSatisfy(exercise) else { return false }
        let names = exercises.compactMap { $0["name"]?.string }
        return optional(v["notes"]) { $0.string != nil } && Set(names).count == names.count
    }

    private static func profile(_ v: JSONValue?) -> Bool {
        guard let p = v, p.object != nil, p["name"]?.string != nil, p["proteinMin"]?.number != nil, p["proteinMax"]?.number != nil else { return false }
        let choices: [String: [String]] = ["units": ["metric", "imperial"], "gymUnit": ["kg", "lb"], "bodyUnit": ["kg", "lb"], "sex": ["male", "female"],
                                           "goal": ["lose", "maintain", "gain"], "lifestyle": ["sitting", "standing", "physical"], "sessionsMode": ["auto", "manual"]]
        for (k, allowed) in choices where !optional(p[k], { $0.string.map(allowed.contains) ?? false }) { return false }
        for k in ["age", "heightCm", "weightKg", "targetWeightKg", "sessionsPerWeek"] where !optional(p[k], { ($0.number ?? -1) >= 0 }) { return false }
        return optional(p["targetDate"]) { validDate($0) }
    }

    private static func log(_ v: JSONValue) -> Bool {
        guard v.object != nil, validDate(v["date"]), v["dayName"]?.string != nil, optional(v["dayIndex"], { weekday($0) }),
              optional(v["unit"], { ["kg", "lb"].contains($0.string ?? "") }), optional(v["done"], { $0.bool != nil }), optional(v["skipped"], { $0.bool != nil }),
              let sets = v["sets"]?.object else { return false }
        let rowsOK = sets.values.allSatisfy { rows in
            rows.array?.allSatisfy { $0.object != nil && $0["weight"]?.string != nil && $0["reps"]?.string != nil } ?? false
        }
        return rowsOK && optional(v["swaps"], { $0.object?.values.allSatisfy { $0.string != nil } ?? false }) && optional(v["template"], day)
    }

    /// Validates the whole file, then reads it. Throws on anything unsound so nothing half-valid is restored.
    public static func parse(_ text: String) throws -> BackupFile {
        guard let data = text.data(using: .utf8), let root = try? JSONDecoder().decode(JSONValue.self, from: data), root.object != nil else { throw BackupError(message: "Not a Fit2216 backup") }
        guard root["app"]?.string == "couple-fit", let plan = root["plan"]?.array, !plan.isEmpty, plan.allSatisfy(day) else { throw BackupError(message: "Invalid backup: plan") }
        let days = plan.compactMap { $0["day"]?.number }
        guard Set(days).count == plan.count, profile(root["profile"]) else { throw BackupError(message: "Invalid backup: profile or days") }
        guard let library = root["library"]?.array, library.allSatisfy({ $0.string != nil }) else { throw BackupError(message: "Invalid backup: library") }
        var templates: [JSONValue]?
        if let t = root["templates"] {
            guard let list = t.array, list.allSatisfy({ x in x["id"]?.string != nil && x["name"]?.string != nil && x["createdAt"]?.string != nil && (x["plan"]?.array?.allSatisfy(day) ?? false) }) else { throw BackupError(message: "Invalid backup: templates") }
            templates = list
        }
        guard let logValues = root["logs"]?.array, logValues.allSatisfy(log), let weightValues = root["weights"]?.array,
              weightValues.allSatisfy({ validDate($0["date"]) && (($0["kg"]?.number ?? 0) > 0) }) else { throw BackupError(message: "Invalid backup: logs or weights") }

        let logs = try logValues.map { v -> WorkoutLog in
            guard let l = v.decoded(WorkoutLog.self) else { throw BackupError(message: "Invalid backup: a workout") }
            return l
        }
        let weights = try weightValues.map { v -> WeightEntry in
            guard let w = v.decoded(WeightEntry.self) else { throw BackupError(message: "Invalid backup: a weigh-in") }
            return w
        }
        guard Set(logs.map(Logging.documentID)).count == logs.count, Set(weights.map(\.date)).count == weights.count else { throw BackupError(message: "Duplicate backup entries") }

        let parsedPlan = JSONValue.array(plan).decoded(LossyArray<TemplateDay>.self)?.elements ?? []
        let profileObject = (root["profile"]?.any as? [String: Any]) ?? [:]
        return BackupFile(plan: parsedPlan, library: library.compactMap(\.string), profile: profileObject, templates: templates?.map(\.any), logs: logs, weights: weights)
    }

    /// The text of a backup from raw documents (as Firestore returns them). Pairing and sharing fields are never exported.
    public static func export(user: [String: Any], logs: [[String: Any]], weights: [[String: Any]], exportedAt: String) -> String? {
        var file = user
        for key in ["partnerUid", "circle", "pending", "macroSync"] { file.removeValue(forKey: key) }
        file["app"] = "couple-fit"
        file["exportedAt"] = exportedAt
        file["logs"] = logs
        file["weights"] = weights
        guard JSONSerialization.isValidJSONObject(file), let data = try? JSONSerialization.data(withJSONObject: file, options: [.prettyPrinted, .sortedKeys]) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
