import XCTest
@testable import ProjectX

final class LLMDecodingTests: XCTestCase {

    // MARK: - ExtractedNutrition Decoding

    func testExtractedNutrition_AllFieldsPresent() throws {
        let json = """
        {
            "calories": 100,
            "protein": 10,
            "carbohydrates": 20,
            "fat": 5,
            "saturatedFat": 2,
            "omega3": 0.5,
            "omega6": 1.0,
            "sugar": 5,
            "fiber": 3,
            "sodium": 100,
            "vitaminA": 50,
            "vitaminC": 30,
            "vitaminD": 5,
            "calcium": 100,
            "iron": 2,
            "potassium": 200
        }
        """

        let nutrition = try JSONDecoder().decode(ExtractedNutrition.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(nutrition.calories, 100)
        XCTAssertEqual(nutrition.protein, 10)
        XCTAssertEqual(nutrition.omega3, 0.5)
        XCTAssertEqual(nutrition.vitaminA, 50)
    }

    func testExtractedNutrition_NullFieldsDefaultToZero() throws {
        let json = """
        {
            "calories": 100,
            "protein": null,
            "carbohydrates": 20,
            "fat": null,
            "saturatedFat": null,
            "omega3": null,
            "omega6": null,
            "sugar": null,
            "fiber": null,
            "sodium": null,
            "vitaminA": null,
            "vitaminC": null,
            "vitaminD": null,
            "calcium": null,
            "iron": null,
            "potassium": null
        }
        """

        let nutrition = try JSONDecoder().decode(ExtractedNutrition.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(nutrition.calories, 100)
        XCTAssertEqual(nutrition.protein, 0)
        XCTAssertEqual(nutrition.fat, 0)
        XCTAssertEqual(nutrition.omega3, 0)
    }

    func testExtractedNutrition_MissingFieldsDefaultToZero() throws {
        let json = """
        {
            "calories": 100,
            "protein": 10,
            "carbohydrates": 20,
            "fat": 5
        }
        """

        let nutrition = try JSONDecoder().decode(ExtractedNutrition.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(nutrition.calories, 100)
        XCTAssertEqual(nutrition.saturatedFat, 0)
        XCTAssertEqual(nutrition.omega3, 0)
        XCTAssertEqual(nutrition.vitaminA, 0)
    }

    func testExtractedNutrition_EmptyObjectDefaultsAllToZero() throws {
        let json = "{}"

        let nutrition = try JSONDecoder().decode(ExtractedNutrition.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(nutrition.calories, 0)
        XCTAssertEqual(nutrition.protein, 0)
        XCTAssertEqual(nutrition.carbohydrates, 0)
        XCTAssertEqual(nutrition.fat, 0)
    }

    // MARK: - ExtractedReceipt Date Parsing

    func testExtractedReceipt_ParsesISODate() {
        let receipt = ExtractedReceipt(storeName: nil, receiptDate: "2025-01-25", items: [])

        let date = receipt.parsedDate

        XCTAssertNotNil(date)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.year, from: date!), 2025)
        XCTAssertEqual(calendar.component(.month, from: date!), 1)
        XCTAssertEqual(calendar.component(.day, from: date!), 25)
    }

    func testExtractedReceipt_ParsesUSDate() {
        let receipt = ExtractedReceipt(storeName: nil, receiptDate: "01/25/2025", items: [])

        let date = receipt.parsedDate

        XCTAssertNotNil(date)
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.month, from: date!), 1)
        XCTAssertEqual(calendar.component(.day, from: date!), 25)
    }

    func testExtractedReceipt_ParsesTextDate() {
        let receipt = ExtractedReceipt(storeName: nil, receiptDate: "Jan 25, 2025", items: [])

        let date = receipt.parsedDate

        XCTAssertNotNil(date)
    }

    func testExtractedReceipt_NilDateReturnsNil() {
        let receipt = ExtractedReceipt(storeName: nil, receiptDate: nil, items: [])
        XCTAssertNil(receipt.parsedDate)
    }

    func testExtractedReceipt_InvalidDateReturnsNil() {
        let receipt = ExtractedReceipt(storeName: nil, receiptDate: "not a date", items: [])
        XCTAssertNil(receipt.parsedDate)
    }

    // MARK: - FoodMatch Decoding

    func testFoodMatch_DecodesCorrectly() throws {
        let json = """
        {
            "foodName": "Milk",
            "confidence": 0.85,
            "isNewFood": false
        }
        """

        let match = try JSONDecoder().decode(FoodMatch.self, from: json.data(using: .utf8)!)

        XCTAssertEqual(match.foodName, "Milk")
        XCTAssertEqual(match.confidence, 0.85)
        XCTAssertFalse(match.isNewFood)
    }

    func testFoodMatch_NullFoodName() throws {
        let json = """
        {
            "foodName": null,
            "confidence": 0.3,
            "isNewFood": true
        }
        """

        let match = try JSONDecoder().decode(FoodMatch.self, from: json.data(using: .utf8)!)

        XCTAssertNil(match.foodName)
        XCTAssertTrue(match.isNewFood)
    }

    // MARK: - LLMError

    func testLLMError_Descriptions() {
        XCTAssertNotNil(LLMError.invalidAPIKey.errorDescription)
        XCTAssertNotNil(LLMError.invalidResponse.errorDescription)
        XCTAssertNotNil(LLMError.rateLimited.errorDescription)
        XCTAssertNotNil(LLMError.parseError("test").errorDescription)

        XCTAssertTrue(LLMError.parseError("test error").errorDescription!.contains("test error"))
    }
}
