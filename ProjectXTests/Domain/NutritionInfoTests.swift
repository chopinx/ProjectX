import XCTest
@testable import ProjectX

final class NutritionInfoTests: XCTestCase {

    // MARK: - Scaled by Grams

    func testScaledByGrams_100g_NoChange() {
        let nutrition = NutritionInfo(
            calories: 100, protein: 10, carbohydrates: 20, fat: 5,
            saturatedFat: 2, omega3: 0.5, omega6: 1.0,
            sugar: 5, fiber: 3, sodium: 100,
            vitaminA: 50, vitaminC: 30, vitaminD: 5, calcium: 100, iron: 2, potassium: 200
        )

        let scaled = nutrition.scaled(byGrams: 100)

        XCTAssertEqual(scaled.calories, 100, accuracy: 0.001)
        XCTAssertEqual(scaled.protein, 10, accuracy: 0.001)
        XCTAssertEqual(scaled.omega3, 0.5, accuracy: 0.001)
    }

    func testScaledByGrams_200g_DoubleValues() {
        let nutrition = NutritionInfo(
            calories: 100, protein: 10, carbohydrates: 20, fat: 5
        )

        let scaled = nutrition.scaled(byGrams: 200)

        XCTAssertEqual(scaled.calories, 200, accuracy: 0.001)
        XCTAssertEqual(scaled.protein, 20, accuracy: 0.001)
        XCTAssertEqual(scaled.carbohydrates, 40, accuracy: 0.001)
        XCTAssertEqual(scaled.fat, 10, accuracy: 0.001)
    }

    func testScaledByGrams_50g_HalfValues() {
        let nutrition = NutritionInfo(
            calories: 100, protein: 10, carbohydrates: 20, fat: 5
        )

        let scaled = nutrition.scaled(byGrams: 50)

        XCTAssertEqual(scaled.calories, 50, accuracy: 0.001)
        XCTAssertEqual(scaled.protein, 5, accuracy: 0.001)
    }

    func testScaledByGrams_ZeroGrams_ZeroValues() {
        let nutrition = NutritionInfo(calories: 100, protein: 10)
        let scaled = nutrition.scaled(byGrams: 0)

        XCTAssertEqual(scaled.calories, 0, accuracy: 0.001)
        XCTAssertEqual(scaled.protein, 0, accuracy: 0.001)
    }

    func testScaledByGrams_PreservesSource() {
        let nutrition = NutritionInfo(source: .labelScan, calories: 100)
        let scaled = nutrition.scaled(byGrams: 200)

        XCTAssertEqual(scaled.source, .labelScan)
    }

    // MARK: - Default Values

    func testDefaultValuesAreZero() {
        let nutrition = NutritionInfo()

        XCTAssertEqual(nutrition.calories, 0)
        XCTAssertEqual(nutrition.protein, 0)
        XCTAssertEqual(nutrition.omega3, 0)
        XCTAssertEqual(nutrition.omega6, 0)
        XCTAssertEqual(nutrition.vitaminA, 0)
        XCTAssertEqual(nutrition.vitaminC, 0)
        XCTAssertEqual(nutrition.vitaminD, 0)
        XCTAssertEqual(nutrition.calcium, 0)
        XCTAssertEqual(nutrition.iron, 0)
        XCTAssertEqual(nutrition.potassium, 0)
    }

    func testDefaultSourceIsManual() {
        let nutrition = NutritionInfo()
        XCTAssertEqual(nutrition.source, .manual)
    }

    // MARK: - Copy Values

    func testCopyValues_CopiesAllFields() {
        let source = NutritionInfo(
            source: .aiEstimate,
            calories: 100, protein: 10, carbohydrates: 20, fat: 5,
            saturatedFat: 2, omega3: 0.5, omega6: 1.0,
            sugar: 5, fiber: 3, sodium: 100,
            vitaminA: 50, vitaminC: 30, vitaminD: 5, calcium: 100, iron: 2, potassium: 200
        )
        let target = NutritionInfo()

        target.copyValues(from: source)

        XCTAssertEqual(target.source, .aiEstimate)
        XCTAssertEqual(target.calories, 100)
        XCTAssertEqual(target.protein, 10)
        XCTAssertEqual(target.omega3, 0.5)
        XCTAssertEqual(target.vitaminA, 50)
    }

    // MARK: - Source Enum

    func testNutritionSourceIcons() {
        XCTAssertEqual(NutritionSource.aiEstimate.icon, "sparkles")
        XCTAssertEqual(NutritionSource.labelScan.icon, "camera.viewfinder")
        XCTAssertEqual(NutritionSource.manual.icon, "pencil")
    }
}
