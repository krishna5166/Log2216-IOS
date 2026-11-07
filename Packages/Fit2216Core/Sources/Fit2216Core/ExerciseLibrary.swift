import Foundation

/// The list of exercise names offered by autocomplete.
public enum ExerciseLibrary {
    /// The library without half-typed leftovers ("B", "Ba", "Barb" saved while typing "Barbell squats"),
    /// blank entries and repeats. A name is dropped only when another entry starts with it (ignoring case);
    /// names the plan uses are always kept. Sorted like the app keeps it.
    public static func cleaned(_ library: [String], keeping planNames: [String] = []) -> [String] {
        let tidy = Set(library.map(ExerciseNames.tidy).filter { !$0.isEmpty })
        let keep = Set(planNames.map { ExerciseNames.tidy($0).lowercased() })
        let lower = tidy.map { $0.lowercased() }
        let kept = tidy.filter { name in
            let l = name.lowercased()
            if keep.contains(l) { return true }
            return !lower.contains { $0.count > l.count && $0.hasPrefix(l) }
        }
        // Same name in two cases ("Cable fly", "Cable Fly"): keep one, preferring the plan's spelling.
        var byLower: [String: String] = [:]
        for n in kept.sorted() {
            let l = n.lowercased()
            if byLower[l] == nil || planNames.contains(n) { byLower[l] = n }
        }
        return byLower.values.sorted()
    }
}
