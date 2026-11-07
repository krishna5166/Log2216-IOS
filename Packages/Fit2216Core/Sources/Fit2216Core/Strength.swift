import Foundation

/// Which lifts a strength graph covers.
public enum StrengthFilter: Hashable, Sendable {
    case overall, lower, upper
    case muscle(Muscle)

    public var label: String {
        switch self {
        case .overall: return "Overall"
        case .lower: return "Lower body"
        case .upper: return "Upper body"
        case .muscle(let m): return m.label
        }
    }

    /// Overall, Lower body, Upper body, then every muscle.
    public static var all: [StrengthFilter] { [.overall, .lower, .upper] + Muscle.allCases.map { .muscle($0) } }

    static let lowerMuscles: Set<Muscle> = [.quads, .hamstrings, .glutes, .adductors, .calves, .lowerback]
    static let upperMuscles: Set<Muscle> = [.chest, .shoulders, .biceps, .triceps, .forearms, .traps, .lats]

    func includes(_ muscles: [Muscle]) -> Bool {
        switch self {
        case .overall: return true
        case .lower: return muscles.contains { Self.lowerMuscles.contains($0) }
        case .upper: return muscles.contains { Self.upperMuscles.contains($0) }
        case .muscle(let m): return muscles.contains(m)
        }
    }
}

/// One week of a strength series.
public struct StrengthWeek: Equatable, Sendable {
    public var start: String       // Monday
    public var volume: Double      // kg x reps, summed over the covered lifts
    public var score: Double?      // blended index, 100 = where the covered lifts started in this window; nil when nothing was lifted that week
    public var volumeIndex: Double? // the main signal alone (100 = start of window)
    public var e1rmIndex: Double?   // the secondary signal alone (100 = start of window)
}

public struct StrengthSeries: Equatable, Sendable {
    public var filter: StrengthFilter
    public var weeks: [StrengthWeek]
    public var sessions: Int       // distinct training days that included these lifts in the window
    public var enough: Bool        // enough sessions for the line to mean something
}

/// Overall strength progress, blended from two signals: weekly volume (weight x reps, the main signal, 70%) and the best
/// estimated one-rep max (the secondary signal, 30%). One-rep max alone only tracks peaks; volume alone rewards junk volume.
/// Each lift is indexed against its own first active week in the window, so a heavy lift does not drown a light one.
/// The Insights graph and the set-page sparkline both read this, so they always agree.
public enum Strength {
    public static let volumeShare = 0.7
    public static let minSessions = 3

    private struct LiftWeek { var volume = 0.0; var e1rm = 0.0 }

    private struct Data {
        var starts: [String]
        var lifts: [String: [Int: LiftWeek]]   // lift -> week index -> totals
        var muscles: [String: [Muscle]]        // lift -> primary muscles
        var dates: [String: Set<String>]       // lift -> training days in the window
    }

    private static func gather(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, weeks: Int, _ cal: Calendar) -> Data {
        let thisMonday = Dates.localDate(Dates.monday(of: now, cal), cal)
        let starts = (0..<weeks).map { Dates.addDays(thisMonday, -7 * (weeks - 1 - $0), cal) }
        var data = Data(starts: starts, lifts: [:], muscles: [:], dates: [:])
        for log in logs where log.skipped != true {
            guard let idx = starts.firstIndex(where: { log.date >= $0 && log.date < Dates.addDays($0, 7, cal) }) else { continue }
            let day = log.template ?? plan.first { Plan.matches(log, $0) }
            for (orig, sets) in log.sets {
                let name = Plan.effectiveName(log, orig)
                for s in sets where Plan.filled(s) {
                    let w = Units.toKg(Insights.num(s.weight), from: Units.logUnit(log)), r = Insights.num(s.reps)
                    guard w > 0, r > 0 else { continue } // bodyweight and empty sets carry no load to compare
                    var lw = data.lifts[name, default: [:]][idx] ?? LiftWeek()
                    lw.volume += w * r
                    lw.e1rm = max(lw.e1rm, Insights.e1rm(weight: w, reps: r))
                    data.lifts[name, default: [:]][idx] = lw
                    data.dates[name, default: []].insert(log.date)
                }
                if data.muscles[name] == nil {
                    let exercise = day?.exercises.first { $0.name == orig && name == orig } ?? TemplateExercise(name: name, sets: 1, reps: "")
                    data.muscles[name] = Muscles.forExercise(exercise).primary
                }
            }
        }
        return data
    }

    private static func series(_ data: Data, lifts names: [String], filter: StrengthFilter) -> StrengthSeries {
        var baselines: [String: LiftWeek] = [:]
        for n in names {
            if let first = data.lifts[n]?.keys.sorted().first, let lw = data.lifts[n]?[first] { baselines[n] = lw }
        }
        var days = Set<String>()
        for n in names { days.formUnion(data.dates[n] ?? []) }

        let weeks: [StrengthWeek] = data.starts.enumerated().map { i, start in
            var volume = 0.0, volIdx: [Double] = [], e1Idx: [Double] = []
            for n in names {
                guard let lw = data.lifts[n]?[i], let base = baselines[n], base.volume > 0, base.e1rm > 0 else { continue }
                volume += lw.volume
                volIdx.append(lw.volume / base.volume)
                e1Idx.append(lw.e1rm / base.e1rm)
            }
            guard !volIdx.isEmpty else { return StrengthWeek(start: start, volume: 0, score: nil, volumeIndex: nil, e1rmIndex: nil) }
            let v = volIdx.reduce(0, +) / Double(volIdx.count), e = e1Idx.reduce(0, +) / Double(e1Idx.count)
            return StrengthWeek(start: start, volume: volume, score: 100 * (volumeShare * v + (1 - volumeShare) * e), volumeIndex: 100 * v, e1rmIndex: 100 * e)
        }
        return StrengthSeries(filter: filter, weeks: weeks, sessions: days.count, enough: days.count >= minSessions)
    }

    /// The series for each filter, in `StrengthFilter.all` order. Filters with no lifts at all are left out.
    public static func series(plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, weeks: Int = 12, _ cal: Calendar = .current) -> [StrengthSeries] {
        let data = gather(plan: plan, logs: logs, now, weeks: weeks, cal)
        return StrengthFilter.all.compactMap { filter in
            let names = data.lifts.keys.filter { filter.includes(data.muscles[$0] ?? []) }.sorted()
            return names.isEmpty ? nil : series(data, lifts: names, filter: filter)
        }
    }

    /// One lift's overall progress (volume and intensity blended), for the sparkline on its set page.
    public static func lift(_ name: String, plan: [TemplateDay], logs: [WorkoutLog], _ now: Date, weeks: Int = 12, _ cal: Calendar = .current) -> StrengthSeries {
        let data = gather(plan: plan, logs: logs, now, weeks: weeks, cal)
        return series(data, lifts: [name], filter: .overall)
    }
}

extension StrengthSeries {
    /// One plain sentence for VoiceOver (and anywhere a chart has no text): which way strength is heading and by how much.
    public var summary: String {
        let scores = weeks.compactMap(\.score)
        guard enough, scores.count >= 2, let first = scores.first, let last = scores.last, first > 0 else {
            return "\(filter.label): not enough sessions yet to show a trend."
        }
        let change = Int(((last / first - 1) * 100).rounded())
        if change == 0 { return "\(filter.label): strength is steady since the first week shown." }
        return "\(filter.label): strength is \(change > 0 ? "up" : "down") \(abs(change)) percent since the first week shown."
    }
}
