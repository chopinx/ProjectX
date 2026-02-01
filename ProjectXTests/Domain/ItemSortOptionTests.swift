import XCTest
@testable import ProjectX

final class ItemSortOptionTests: XCTestCase {

    // MARK: - All Cases

    func testAllCasesCount() {
        XCTAssertEqual(ItemSortOption.allCases.count, 9)
    }

    func testRawValues() {
        XCTAssertEqual(ItemSortOption.recent.rawValue, "Recent")
        XCTAssertEqual(ItemSortOption.name.rawValue, "Name")
        XCTAssertEqual(ItemSortOption.calories.rawValue, "Calories")
        XCTAssertEqual(ItemSortOption.protein.rawValue, "Protein")
        XCTAssertEqual(ItemSortOption.carbs.rawValue, "Carbs")
        XCTAssertEqual(ItemSortOption.fat.rawValue, "Fat")
        XCTAssertEqual(ItemSortOption.fiber.rawValue, "Fiber")
        XCTAssertEqual(ItemSortOption.sugar.rawValue, "Sugar")
        XCTAssertEqual(ItemSortOption.price.rawValue, "Price")
    }

    // MARK: - Icons

    func testIcons() {
        XCTAssertEqual(ItemSortOption.recent.icon, "clock")
        XCTAssertEqual(ItemSortOption.name.icon, "textformat")
        XCTAssertEqual(ItemSortOption.calories.icon, "flame")
        XCTAssertEqual(ItemSortOption.fiber.icon, "leaf")
        XCTAssertEqual(ItemSortOption.price.icon, "dollarsign.circle")
    }

    // MARK: - Value Extraction

    func testValueForItem_RecentAndName_ReturnZero() {
        let item = PurchasedItem(name: "Test", quantity: 100, price: 5.0)

        XCTAssertEqual(ItemSortOption.recent.value(for: item), 0)
        XCTAssertEqual(ItemSortOption.name.value(for: item), 0)
    }

    func testValueForItem_Price() {
        let item = PurchasedItem(name: "Test", quantity: 100, price: 5.99)
        XCTAssertEqual(ItemSortOption.price.value(for: item), 5.99)
    }

    func testValueForItem_NutritionValues_WithFood() {
        let nutrition = NutritionInfo(
            calories: 200, protein: 10, carbohydrates: 30, fat: 8,
            sugar: 5
        )
        let food = Food(name: "Test Food", category: .other, nutrition: nutrition)
        let item = PurchasedItem(name: "Test", quantity: 100, price: 5.0, food: food)

        // For 100g, values should match nutrition per 100g
        XCTAssertEqual(ItemSortOption.calories.value(for: item), 200, accuracy: 0.001)
        XCTAssertEqual(ItemSortOption.protein.value(for: item), 10, accuracy: 0.001)
        XCTAssertEqual(ItemSortOption.carbs.value(for: item), 30, accuracy: 0.001)
        XCTAssertEqual(ItemSortOption.fat.value(for: item), 8, accuracy: 0.001)
        XCTAssertEqual(ItemSortOption.sugar.value(for: item), 5, accuracy: 0.001)
    }

    func testValueForItem_NutritionValues_Scaled() {
        let nutrition = NutritionInfo(calories: 100, protein: 10)
        let food = Food(name: "Test Food", category: .other, nutrition: nutrition)
        let item = PurchasedItem(name: "Test", quantity: 200, price: 5.0, food: food)

        // For 200g, values should be doubled
        XCTAssertEqual(ItemSortOption.calories.value(for: item), 200, accuracy: 0.001)
        XCTAssertEqual(ItemSortOption.protein.value(for: item), 20, accuracy: 0.001)
    }

    func testValueForItem_NutritionValues_WithoutFood() {
        let item = PurchasedItem(name: "Test", quantity: 100, price: 5.0, food: nil)

        XCTAssertEqual(ItemSortOption.calories.value(for: item), 0)
        XCTAssertEqual(ItemSortOption.protein.value(for: item), 0)
    }

    func testValueForItem_NutritionValues_FoodWithoutNutrition() {
        let food = Food(name: "Test Food", category: .other, nutrition: nil)
        let item = PurchasedItem(name: "Test", quantity: 100, price: 5.0, food: food)

        XCTAssertEqual(ItemSortOption.calories.value(for: item), 0)
    }

    // MARK: - Identifiable

    func testIdMatchesRawValue() {
        for option in ItemSortOption.allCases {
            XCTAssertEqual(option.id, option.rawValue)
        }
    }
}
