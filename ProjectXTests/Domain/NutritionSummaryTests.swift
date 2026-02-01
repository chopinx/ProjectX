import XCTest
@testable import ProjectX

final class NutritionSummaryTests: XCTestCase {
    func testSummaryForSingleTripSingleItem() {
        // Given a food with nutrition per 100g
        let nutrition = NutritionInfo(
            calories: 350, protein: 12, carbohydrates: 70, fat: 2,
            saturatedFat: 0.5, sugar: 2, fiber: 3, sodium: 5
        )
        let pasta = Food(name: "Pasta", category: FoodCategory(main: .grains, sub: .pastaNoodles), nutrition: nutrition)

        // And a trip with 500g of that food
        let trip = GroceryTrip(date: Date(), storeName: "Test Store")
        let item = PurchasedItem(name: "Pasta", quantity: 500, price: 2.99, food: pasta)
        trip.items.append(item)

        // When we compute a summary
        let summary = NutritionSummary.forTrips([trip])

        // Then values scale by quantity (500g = 5x 100g)
        XCTAssertEqual(summary.totalCalories, 350 * 5, accuracy: 0.001)
        XCTAssertEqual(summary.totalProtein, 12 * 5, accuracy: 0.001)
        XCTAssertEqual(summary.totalCarbohydrates, 70 * 5, accuracy: 0.001)
        XCTAssertEqual(summary.totalFat, 2 * 5, accuracy: 0.001)
    }

    func testSummaryForMultipleTripsAndItems() {
        let appleNutrition = NutritionInfo(
            calories: 52, protein: 0.3, carbohydrates: 14, fat: 0.2,
            saturatedFat: 0.0, sugar: 10, fiber: 2.4, sodium: 1
        )
        let apple = Food(name: "Apple", category: FoodCategory(main: .fruits, sub: .tropicalFruits), nutrition: appleNutrition)

        let milkNutrition = NutritionInfo(
            calories: 64, protein: 3.4, carbohydrates: 4.8, fat: 3.7,
            saturatedFat: 2.4, sugar: 4.8, fiber: 0, sodium: 44
        )
        let milk = Food(name: "Milk", category: FoodCategory(main: .dairy, sub: .milkAlternatives), nutrition: milkNutrition)

        // Trip 1: 450g apples + 1000g milk
        let trip1 = GroceryTrip(date: Date(), storeName: "Store A")
        trip1.items.append(PurchasedItem(name: "Apples", quantity: 450, price: 3.0, food: apple))
        trip1.items.append(PurchasedItem(name: "Milk 1L", quantity: 1000, price: 1.2, food: milk))

        // Trip 2: 300g apples
        let trip2 = GroceryTrip(date: Date(), storeName: "Store B")
        trip2.items.append(PurchasedItem(name: "Apples", quantity: 300, price: 2.0, food: apple))

        let summary = NutritionSummary.forTrips([trip1, trip2])

        // Verify totals are computed
        XCTAssertGreaterThan(summary.totalCalories, 0)
        XCTAssertGreaterThan(summary.totalProtein, 0)
        XCTAssertGreaterThan(summary.totalCarbohydrates, 0)
        XCTAssertGreaterThan(summary.totalFat, 0)
    }

    func testSummaryExcludesItemsWithoutFood() {
        let trip = GroceryTrip(date: Date(), storeName: "Test")
        trip.items.append(PurchasedItem(name: "Unknown Item", quantity: 500, price: 5.0, food: nil))

        let summary = NutritionSummary.forTrips([trip])

        XCTAssertEqual(summary.totalCalories, 0)
    }
}
