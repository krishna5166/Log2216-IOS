import Foundation

/// One food as the AI worked it out.
public struct Meal: Codable, Equatable, Sendable {
    public var name: String
    public var kcal: Double
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    public init(name: String, kcal: Double, protein: Double, carbs: Double, fat: Double) { self.name = name; self.kcal = kcal; self.protein = protein; self.carbs = carbs; self.fat = fat }
}

/// One entry you added: the text you wrote and the foods made of it (summed on the card).
public struct FoodCard: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var text: String
    public var items: [Meal]
    public init(id: String, text: String, items: [Meal]) { self.id = id; self.text = text; self.items = items }

    private enum Keys: String, CodingKey { case id, text, items }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        text = (try? c.decode(String.self, forKey: .text)) ?? ""
        items = (try? c.decode(LossyArray<Meal>.self, forKey: .items))?.elements ?? []
    }
    public var totals: Totals { Food.totals(items) }
    public var title: String { String(text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "\n", omittingEmptySubsequences: false).first ?? "").prefix(60).description }
}

/// One day of food: the cards, the unsent text in the box, and the day's completion %.
public struct FoodDay: Codable, Equatable, Sendable {
    public var cards: [FoodCard]
    public var draft: String?
    public var pct: Int?
    public init(cards: [FoodCard] = [], draft: String? = nil, pct: Int? = nil) { self.cards = cards; self.draft = draft; self.pct = pct }

    private enum Keys: String, CodingKey { case cards, draft, pct }
    public init(from decoder: Decoder) throws {
        let c = try? decoder.container(keyedBy: Keys.self)
        cards = (try? c?.decodeIfPresent(LossyArray<FoodCard>.self, forKey: .cards))??.elements ?? []
        draft = c?.lenientString(.draft)
        pct = c?.lenientInt(.pct)
    }
}

public struct Totals: Equatable, Sendable {
    public var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
    public init(kcal: Double = 0, protein: Double = 0, carbs: Double = 0, fat: Double = 0) { self.kcal = kcal; self.protein = protein; self.carbs = carbs; self.fat = fat }
}

public enum MacroKey: String, CaseIterable, Sendable { case kcal, protein, carbs, fat }

public struct MacroStatus: Equatable, Sendable {
    public enum State: Sendable { case none, under, hit, over }
    public var key: MacroKey
    public var value: Double
    public var target: Int?
    public var state: State
    public var delta: Int
}

/// Meal totals, hit-or-miss per macro and day completion. A port of the rules in app/src/lib/food.ts.
public enum Food {
    public static func totals(_ meals: [Meal]) -> Totals {
        meals.reduce(Totals()) { Totals(kcal: $0.kcal + $1.kcal, protein: $0.protein + $1.protein, carbs: $0.carbs + $1.carbs, fat: $0.fat + $1.fat) }
    }
    public static func dayTotals(_ cards: [FoodCard]) -> Totals { totals(cards.flatMap(\.items)) }

    private static func value(_ t: Totals, _ k: MacroKey) -> Double {
        switch k { case .kcal: return t.kcal; case .protein: return t.protein; case .carbs: return t.carbs; case .fat: return t.fat }
    }
    private static func target(_ t: Targets, _ k: MacroKey) -> Int {
        switch k { case .kcal: return t.kcal; case .protein: return t.protein; case .carbs: return t.carbs; case .fat: return t.fat }
    }

    /// Protein is a floor (at or above your minimum is a hit, and there is no "over"); calories, carbs and fat are hits within ±10% of the target.
    public static func status(_ key: MacroKey, value: Double, targets: Targets?) -> MacroStatus {
        guard let targets, target(targets, key) > 0 else { return MacroStatus(key: key, value: value, target: nil, state: .none, delta: 0) }
        let tgt = target(targets, key)
        if key == .protein {
            let floor = targets.proteinMin > 0 ? targets.proteinMin : tgt
            return MacroStatus(key: key, value: value, target: tgt, state: value >= Double(floor) ? .hit : .under, delta: Nutrition.round(Double(floor) - value))
        }
        let t = Double(tgt)
        let state: MacroStatus.State = value < t * 0.9 ? .under : value > t * 1.1 ? .over : .hit
        return MacroStatus(key: key, value: value, target: tgt, state: state, delta: Int((t - value).rounded()))
    }

    /// The average of the four macro ratios, each clamped to 0...100. Nil without targets.
    public static func completionPercent(_ t: Totals, targets: Targets?) -> Int? {
        guard let targets, targets.kcal > 0, targets.protein > 0, targets.carbs > 0, targets.fat > 0 else { return nil }
        let ratios = MacroKey.allCases.map { k in min(100, max(0, value(t, k) / Double(target(targets, k)) * 100)) }
        return Nutrition.round(ratios.reduce(0, +) / 4)
    }

    /// The same food written a little differently ("2 Eggs ", "2 eggs.") reads as the same text. Quantities and words are never merged.
    public static func normalize(_ text: String) -> String {
        var s = text.lowercased().replacingOccurrences(of: "\r\n", with: "\n")
        s = s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: " ?\\n ?", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "[.,;!]+(?=\\n|$)", with: "", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
