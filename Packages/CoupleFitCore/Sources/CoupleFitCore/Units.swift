import Foundation

public enum Units {
    public static let kgPerLb = 0.45359237
    public static func lbToKg(_ lb: Double) -> Double { lb * kgPerLb }
    public static func kgToLb(_ kg: Double) -> Double { kg / kgPerLb }

    /// Set weights are typed in a unit and each log remembers which one (logs from before this existed are kg).
    public static func logUnit(_ log: WorkoutLog) -> WeightUnit { log.unit ?? .kg }

    public static func toKg(_ w: Double, from: WeightUnit) -> Double { from == .kg ? w : lbToKg(w) }
    public static func fromKg(_ kg: Double, to: WeightUnit) -> Double { to == .kg ? kg : kgToLb(kg) }
    public static func convert(_ w: Double, from: WeightUnit, to: WeightUnit) -> Double { from == to ? w : fromKg(toKg(w, from: from), to: to) }

    /// One decimal place, no trailing ".0" (135 → "135", 22.46 → "22.5"). Rounds half up like the web app.
    public static func tidy(_ n: Double) -> String {
        let r = (n * 10 + 0.5).rounded(.down) / 10
        return r == r.rounded() ? String(Int(r)) : String(r)
    }

    /// Converts a typed weight between units. Empty and non-numeric text passes through unchanged.
    public static func convertWeightString(_ s: String, from: WeightUnit, to: WeightUnit) -> String {
        if s.isEmpty || from == to { return s }
        guard let v = Double(s), v.isFinite else { return s }
        return tidy(convert(v, from: from, to: to))
    }

    /// True once any set in the log has a weight or reps typed in.
    public static func hasSets(_ log: WorkoutLog) -> Bool {
        log.sets.values.contains { rows in rows.contains { !$0.weight.isEmpty || !$0.reps.isEmpty } }
    }
}
