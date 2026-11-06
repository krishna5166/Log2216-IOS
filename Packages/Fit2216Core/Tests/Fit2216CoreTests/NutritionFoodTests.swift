import XCTest
@testable import Fit2216Core

final class NutritionFoodTests: XCTestCase {
    private let man = Profile(name: "A", heightCm: 175, goal: .lose, sex: .male, age: 30, weightKg: 80, lifestyle: .sitting)

    func testTargetsMatchTheWebAppsFormula() {
        // BMR = 10*80 + 6.25*175 - 5*30 + 5 = 1748.75; TDEE = 1748.75*1.2 + 3*300/7 = 2227.07; lose = *0.8 = 1782.3 -> 1780
        let t = Nutrition.computeTargets(man, autoSessions: 3)!
        XCTAssertEqual(t.bmr, 1749); XCTAssertEqual(t.tdee, 2227); XCTAssertEqual(t.kcal, 1780)
        XCTAssertEqual(t.protein, 160); XCTAssertEqual(t.proteinMin, 144); XCTAssertEqual(t.proteinMax, 176)
        XCTAssertEqual(t.fat, 56); XCTAssertEqual(t.carbs, 159) // max(round(.25*1780/9)=49, round(.7*80)=56); (1780-640-504)/4 = 159
        XCTAssertEqual(t.sessions, 3)
    }

    func testWomanMaintainAndGainDifferByGoalFactorAndProtein() {
        var p = Profile(name: "B", heightCm: 165, goal: .maintain, sex: .female, age: 28, weightKg: 60, lifestyle: .standing)
        let m = Nutrition.computeTargets(p, autoSessions: 0)!
        p.goal = .gain
        let g = Nutrition.computeTargets(p, autoSessions: 0)!
        XCTAssertEqual(Double(g.kcal) / Double(m.kcal), 1.1, accuracy: 0.01)
        XCTAssertEqual(m.protein, 108) // (1.6+2.0)/2*60
    }

    func testNoTargetsWithoutBodyDetailsAndManualSessionsAreCapped() {
        XCTAssertNil(Nutrition.computeTargets(Profile(name: "x"), autoSessions: 3))
        XCTAssertFalse(Nutrition.hasBodyDetails(Profile(heightCm: 175, sex: .male, age: 0, weightKg: 80)))
        var p = man; p.sessionsMode = .manual; p.sessionsPerWeek = 12
        XCTAssertEqual(Nutrition.computeTargets(p, autoSessions: 1)!.sessions, 7)
    }

    func testAverageSessionsFromLoggedWorkoutsOrThePlan() {
        let now = day(2026, 10, 28)
        let plan = [trainingDay(1, "A"), trainingDay(2, "B"), trainingDay(3, "C"), restDay(4)]
        XCTAssertEqual(Nutrition.avgSessions(plan: plan, logs: [], now, cal), 3) // no history: the plan
        let logs = [doneLog("2026-10-26", 1, "A"), doneLog("2026-10-27", 2, "B"), doneLog("2026-10-19", 1, "A"),
                    WorkoutLog(date: "2026-10-20", dayName: "B", dayIndex: 2, skipped: true)]
        // 3 counted, earliest 19 Oct = 10 days back -> 10 days -> 3/(10/7) = 2.1
        XCTAssertEqual(Nutrition.avgSessions(plan: plan, logs: logs, now, cal), 2.1, accuracy: 0.01)
    }

    func testTotalsAndMacroStatus() {
        let meals = [Meal(name: "Eggs", kcal: 140, protein: 12, carbs: 1, fat: 10), Meal(name: "Toast", kcal: 80, protein: 3, carbs: 15, fat: 1)]
        XCTAssertEqual(Food.totals(meals), Totals(kcal: 220, protein: 15, carbs: 16, fat: 11))
        let targets = Nutrition.computeTargets(man, autoSessions: 3)
        XCTAssertEqual(Food.status(.kcal, value: 1700, targets: targets).state, .hit)   // within 10%
        XCTAssertEqual(Food.status(.kcal, value: 1000, targets: targets).state, .under)
        XCTAssertEqual(Food.status(.kcal, value: 2100, targets: targets).state, .over)
        XCTAssertEqual(Food.status(.protein, value: 150, targets: targets).state, .hit)  // floor is proteinMin 144
        XCTAssertEqual(Food.status(.protein, value: 300, targets: targets).state, .hit)  // no "over" for protein
        XCTAssertEqual(Food.status(.protein, value: 100, targets: targets).delta, 44)
        XCTAssertEqual(Food.status(.fat, value: 10, targets: nil).state, .none)
    }

    func testCompletionPercent() {
        let targets = Nutrition.computeTargets(man, autoSessions: 3)!
        XCTAssertEqual(Food.completionPercent(Totals(kcal: 890, protein: 80, carbs: 77, fat: 28), targets: targets), 50)
        XCTAssertEqual(Food.completionPercent(Totals(kcal: 9999, protein: 999, carbs: 999, fat: 999), targets: targets), 100) // clamped
        XCTAssertEqual(Food.completionPercent(Totals(), targets: targets), 0)
        XCTAssertNil(Food.completionPercent(Totals(kcal: 100), targets: nil))
    }

    func testNormalizeTreatsSmallRewritesAsTheSameFood() {
        XCTAssertEqual(Food.normalize("2 Eggs "), Food.normalize("2 eggs."))
        XCTAssertEqual(Food.normalize("Toast  with   butter,\r\n2 eggs;"), "toast with butter\n2 eggs")
        XCTAssertNotEqual(Food.normalize("2 eggs"), Food.normalize("3 eggs"))
    }

    func testFoodDocumentsAreReadLeniently() throws {
        let day = try decode(FoodDay.self, #"{"cards":[{"id":"c1","text":"2 eggs\ntoast","items":[{"name":"Eggs","kcal":140,"protein":12,"carbs":1,"fat":10},{"name":"bad"}]},null],"draft":"x","pct":55}"#)
        XCTAssertEqual(day.cards.count, 1); XCTAssertEqual(day.cards[0].items.count, 1); XCTAssertEqual(day.cards[0].title, "2 eggs"); XCTAssertEqual(day.pct, 55)
        XCTAssertEqual(try decode(FoodDay.self, "{}"), FoodDay())
    }
}
