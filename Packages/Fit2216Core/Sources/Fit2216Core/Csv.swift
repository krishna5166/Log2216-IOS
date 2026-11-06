import Foundation

public struct CsvError: Error, Equatable, CustomStringConvertible {
    public var message: String
    public var description: String { message }
}

public struct CsvImport: Equatable, Sendable {
    public var logs: [WorkoutLog]
    public var weights: [WeightEntry]
}

/// Spreadsheet export and import of workouts and weigh-ins. A port of app/src/lib/csv.ts; the file format is identical.
public enum Csv {
    public static let header = ["kind", "date", "day_index", "day", "exercise", "set", "weight", "reps", "unit", "finished", "skipped"]

    private static let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()

    /// Quotes a cell when needed, and prefixes text a spreadsheet could run as a formula (starts with = + - @ tab or return, and is not a number).
    static func cell(_ value: String) -> String {
        var s = value
        if let first = s.unicodeScalars.first, "=+-@\t\r".unicodeScalars.contains(first), Double(s) == nil { s = "'" + s }
        if s.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) { return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return s
    }

    /// One row per set (kind "set") and per weigh-in (kind "weight", kilograms).
    public static func export(logs: [WorkoutLog], weights: [WeightEntry]) -> String {
        var rows: [[String]] = [header]
        for l in logs.sorted(by: { $0.date < $1.date }) {
            let unit = (l.unit ?? .kg).rawValue
            let index = l.dayIndex.map(String.init) ?? ""
            let done = l.done == true ? "yes" : "", skipped = l.skipped == true ? "yes" : ""
            let names = l.sets.keys.sorted()
            if names.isEmpty { rows.append(["workout", l.date, index, l.dayName, "", "", "", "", unit, done, skipped]) }
            for name in names {
                for (i, s) in (l.sets[name] ?? []).enumerated() { rows.append(["set", l.date, index, l.dayName, name, String(i + 1), s.weight, s.reps, unit, done, skipped]) }
            }
        }
        for w in weights.sorted(by: { $0.date < $1.date }) { rows.append(["weight", w.date, "", "", "", "", Units.tidyKg(w.kg), "", "kg", "", ""]) }
        return rows.map { $0.map(cell).joined(separator: ",") }.joined(separator: "\r\n") + "\r\n"
    }

    /// Splits CSV text into rows of cells, honouring quotes. Throws on an unclosed quote.
    static func records(_ text: String) throws -> [[String]] {
        var out: [[String]] = []
        var row: [String] = [], cur = "", quoted = false
        let chars = Array(text.unicodeScalars.drop(while: { $0 == "\u{FEFF}" }))
        var i = 0
        func endRow() { row.append(cur); cur = ""; if row.contains(where: { !$0.isEmpty }) { out.append(row) }; row = [] }
        while i < chars.count {
            let c = chars[i]
            if quoted {
                if c == "\"" { if i + 1 < chars.count, chars[i + 1] == "\"" { cur.unicodeScalars.append("\""); i += 1 } else { quoted = false } } else { cur.unicodeScalars.append(c) }
            } else if c == "\"" { quoted = true }
            else if c == "," { row.append(cur); cur = "" }
            else if c == "\n" || c == "\r" {
                if c == "\r", i + 1 < chars.count, chars[i + 1] == "\n" { i += 1 }
                endRow()
            } else { cur.unicodeScalars.append(c) }
            i += 1
        }
        if quoted { throw CsvError(message: "Unclosed quote") }
        row.append(cur)
        if row.contains(where: { !$0.isEmpty }) { out.append(row) }
        return out
    }

    /// Reads a file made by `export`. Throws on anything it cannot trust, so nothing half-valid is saved.
    public static func parse(_ text: String) throws -> CsvImport {
        let rows = try records(text)
        guard let first = rows.first, first == header else { throw CsvError(message: "Not a Fit2216 CSV") }
        var logs: [WorkoutLog] = [], logKeys: [String] = []
        var weights: [String: WeightEntry] = [:], weightOrder: [String] = []
        for (n, r) in rows.dropFirst().enumerated() {
            func f(_ i: Int) -> String { i < r.count ? r[i] : "" }
            func bad(_ why: String) -> CsvError { CsvError(message: "Row \(n + 2): \(why)") }
            let kind = f(0), date = f(1), dayIndex = f(2), day = f(3), exercise = f(4), weight = f(6), reps = f(7), unit = f(8), finished = f(9), skipped = f(10)
            guard Dates.parse(date, utc) != nil else { throw bad("bad date") }
            if kind == "weight" {
                guard let kg = Double(weight), kg > 0, kg < 1000 else { throw bad("bad weight") }
                if weights[date] == nil { weightOrder.append(date) }
                weights[date] = WeightEntry(date: date, kg: kg)
                continue
            }
            guard kind == "set" || kind == "workout" else { throw bad("unknown kind") }
            guard let u = WeightUnit(rawValue: unit) else { throw bad("unit must be kg or lb") }
            var idx: Int?
            if !dayIndex.isEmpty {
                guard let v = Int(dayIndex), (0...6).contains(v) else { throw bad("bad day_index") }
                idx = v
            }
            guard !day.isEmpty else { throw bad("missing day") }
            let key = idx.map { "\(date)_\($0)" } ?? date
            var at = logKeys.firstIndex(of: key)
            if at == nil {
                logs.append(WorkoutLog(date: date, dayName: day, dayIndex: idx, unit: u, sets: [:])); logKeys.append(key); at = logs.count - 1
            } else if logs[at!].unit != u { throw bad("one workout cannot mix kg and lb") }
            let i = at!
            if finished == "yes" { logs[i].done = true }
            if skipped == "yes" { logs[i].skipped = true }
            if logs[i].done == true && logs[i].skipped == true { throw bad("a workout cannot be both finished and skipped") }
            if kind == "set" {
                guard !exercise.isEmpty else { throw bad("missing exercise") }
                logs[i].sets[exercise, default: []].append(SetLog(weight: weight, reps: reps))
            }
        }
        return CsvImport(logs: logs, weights: weightOrder.compactMap { weights[$0] })
    }
}

extension Units {
    /// A kilogram value as the web app writes it: no trailing ".0", no float noise.
    static func tidyKg(_ kg: Double) -> String { kg == kg.rounded() ? String(Int(kg)) : String(kg) }
}
