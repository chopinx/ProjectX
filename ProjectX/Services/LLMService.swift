import Foundation
import UIKit

// MARK: - Response Types

struct ExtractedReceipt: Codable {
    var storeName: String?
    var receiptDate: String?  // Date string from receipt (e.g., "2025-01-25" or "Jan 25, 2025")
    var items: [ExtractedReceiptItem]

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case receiptDate = "receipt_date"
        case items
    }

    /// Parse receiptDate string to Date
    var parsedDate: Date? {
        guard let dateStr = receiptDate else { return nil }
        let formatters: [DateFormatter] = {
            let formats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "MMM d, yyyy", "d MMM yyyy", "yyyy/MM/dd"]
            return formats.map { f in let df = DateFormatter(); df.dateFormat = f; return df }
        }()
        for formatter in formatters { if let d = formatter.date(from: dateStr) { return d } }
        return nil
    }
}

struct ExtractedReceiptItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantityGrams: Double  // Always in grams - LLM converts all units
    var price: Double
    var category: String
    var subcategory: String?
    var linkedFoodId: UUID?  // Auto-linked food ID if confidence is high enough

    enum CodingKeys: String, CodingKey {
        case name
        case quantityGrams = "quantity_grams"
        case price
        case category
        case subcategory
    }
}

struct ExtractedNutrition: Decodable {
    var calories, protein, carbohydrates, fat, saturatedFat: Double
    var omega3, omega6, sugar, fiber, sodium: Double
    var vitaminA, vitaminC, vitaminD, calcium, iron, potassium: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func d(_ key: CodingKeys) -> Double { (try? c.decodeIfPresent(Double.self, forKey: key)) ?? 0 }
        calories = d(.calories); protein = d(.protein); carbohydrates = d(.carbohydrates)
        fat = d(.fat); saturatedFat = d(.saturatedFat); omega3 = d(.omega3); omega6 = d(.omega6)
        sugar = d(.sugar); fiber = d(.fiber); sodium = d(.sodium)
        vitaminA = d(.vitaminA); vitaminC = d(.vitaminC); vitaminD = d(.vitaminD)
        calcium = d(.calcium); iron = d(.iron); potassium = d(.potassium)
    }

    private enum CodingKeys: String, CodingKey {
        case calories, protein, carbohydrates, fat, saturatedFat, omega3, omega6
        case sugar, fiber, sodium, vitaminA, vitaminC, vitaminD, calcium, iron, potassium
    }
}

struct FoodMatch: Codable, Identifiable {
    var id: UUID = UUID()
    var foodName: String?
    var confidence: Double
    var isNewFood: Bool

    enum CodingKeys: String, CodingKey {
        case foodName, confidence, isNewFood
    }
}

struct SuggestedFoodInfo: Codable {
    var category: String
    var subcategory: String?
    var tags: [String]
}

struct SuggestedNutritionTargets: Decodable {
    var calories, protein, carbohydrates, fat, saturatedFat: Double
    var omega3, omega6, sugar, fiber, sodium: Double
    var vitaminA, vitaminC, vitaminD, calcium, iron, potassium: Double
    var explanation: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = NutritionTarget.default
        func d(_ key: CodingKeys, _ def: Double) -> Double { (try? c.decodeIfPresent(Double.self, forKey: key)) ?? def }
        calories = d(.calories, t.calories); protein = d(.protein, t.protein); carbohydrates = d(.carbohydrates, t.carbohydrates)
        fat = d(.fat, t.fat); saturatedFat = d(.saturatedFat, t.saturatedFat); omega3 = d(.omega3, t.omega3); omega6 = d(.omega6, t.omega6)
        sugar = d(.sugar, t.sugar); fiber = d(.fiber, t.fiber); sodium = d(.sodium, t.sodium)
        vitaminA = d(.vitaminA, t.vitaminA); vitaminC = d(.vitaminC, t.vitaminC); vitaminD = d(.vitaminD, t.vitaminD)
        calcium = d(.calcium, t.calcium); iron = d(.iron, t.iron); potassium = d(.potassium, t.potassium)
        explanation = (try? c.decodeIfPresent(String.self, forKey: .explanation)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case calories, protein, carbohydrates, fat, saturatedFat, omega3, omega6
        case sugar, fiber, sodium, vitaminA, vitaminC, vitaminD, calcium, iron, potassium, explanation
    }

    func toNutritionTarget() -> NutritionTarget {
        NutritionTarget(calories: calories, protein: protein, carbohydrates: carbohydrates,
                        fat: fat, saturatedFat: saturatedFat, omega3: omega3, omega6: omega6,
                        sugar: sugar, fiber: fiber, sodium: sodium,
                        vitaminA: vitaminA, vitaminC: vitaminC, vitaminD: vitaminD,
                        calcium: calcium, iron: iron, potassium: potassium)
    }
}

// MARK: - Protocol

protocol LLMService {
    /// Validate the API key by making a simple test request
    func validateAPIKey() async throws

    /// Extract items and store name from a receipt image
    func extractReceipt(from image: UIImage, filterBabyFood: Bool) async throws -> ExtractedReceipt

    /// Extract items and store name from receipt text (copy-pasted or typed)
    func extractReceipt(from text: String, filterBabyFood: Bool) async throws -> ExtractedReceipt

    /// Extract nutrition info from a nutrition label image
    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition

    /// Extract nutrition info from nutrition label text (copy-pasted or typed)
    func extractNutritionLabel(from text: String) async throws -> ExtractedNutrition

    /// Estimate nutrition for a food item by name
    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition

    /// Match receipt item to foods in the food bank
    func matchFood(itemName: String, existingFoods: [String]) async throws -> FoodMatch

    /// Suggest category and tags for a food item
    func suggestCategoryAndTags(for foodName: String, availableTags: [String]) async throws -> SuggestedFoodInfo

    /// Suggest daily nutrition targets based on family member profiles
    func suggestNutritionTargets(for members: [FamilyMember]) async throws -> SuggestedNutritionTargets
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your settings."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from AI service."
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        }
    }
}
