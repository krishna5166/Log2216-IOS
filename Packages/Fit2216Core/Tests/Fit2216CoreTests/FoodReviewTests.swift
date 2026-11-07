import XCTest
@testable import Fit2216Core

final class FoodReviewTests: XCTestCase {
    func testAmountsAreClampedRoundedAndNamesTidied() {
        let out = Food.cleaned([
            Meal(name: "  Rice   bowl ", kcal: 412.6, protein: 8.04, carbs: 90.96, fat: 1.25),
            Meal(name: "", kcal: 90000, protein: -5, carbs: 9999, fat: .nan),
        ])
        XCTAssertEqual(out[0], Meal(name: "Rice bowl", kcal: 413, protein: 8, carbs: 91, fat: 1.3))
        XCTAssertEqual(out[1], Meal(name: "Food", kcal: 5000, protein: 0, carbs: 500, fat: 0))
    }

    func testAnEmptyFoodIsDroppedAndLongNamesAreCapped() {
        let out = Food.cleaned([
            Meal(name: "Water", kcal: 0, protein: 0, carbs: 0, fat: 0),
            Meal(name: String(repeating: "x", count: 80), kcal: 10, protein: 0, carbs: 0, fat: 0),
        ])
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[0].name.count, 40)
    }

    func testTotalsFollowTheReviewedItems() {
        let reviewed = Food.cleaned([Meal(name: "Egg", kcal: 78, protein: 6.3, carbs: 0.6, fat: 5.3), Meal(name: "Toast", kcal: 90, protein: 3, carbs: 17, fat: 1)])
        let t = Food.totals(reviewed)
        XCTAssertEqual(t.kcal, 168, accuracy: 0.001)
        XCTAssertEqual(t.protein, 9.3, accuracy: 0.001)
    }
}
