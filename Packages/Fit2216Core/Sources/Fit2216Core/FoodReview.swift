import Foundation

extension Food {
    public static let maxItemKcal = 5000.0
    public static let maxItemGrams = 500.0

    /// A reviewed estimate made safe to save: names tidied and capped at 40 characters, amounts kept inside plausible ranges
    /// (calories 0 to 5000, grams 0 to 500 per food), calories rounded to whole numbers and grams to one decimal.
    /// A food whose four amounts are all zero is dropped, since it adds nothing.
    public static func cleaned(_ items: [Meal]) -> [Meal] {
        func clamp(_ v: Double, _ hi: Double) -> Double { v.isFinite ? min(max(v, 0), hi) : 0 }
        return items.compactMap { m in
            let kcal = clamp(m.kcal, maxItemKcal).rounded()
            let protein = (clamp(m.protein, maxItemGrams) * 10).rounded() / 10
            let carbs = (clamp(m.carbs, maxItemGrams) * 10).rounded() / 10
            let fat = (clamp(m.fat, maxItemGrams) * 10).rounded() / 10
            if kcal == 0 && protein == 0 && carbs == 0 && fat == 0 { return nil }
            let name = ExerciseNames.tidy(m.name)
            return Meal(name: name.isEmpty ? "Food" : String(name.prefix(40)), kcal: kcal, protein: protein, carbs: carbs, fat: fat)
        }
    }
}
