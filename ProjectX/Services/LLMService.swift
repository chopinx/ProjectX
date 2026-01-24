import Foundation
import UIKit

// MARK: - Response Types

struct ExtractedReceiptItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantityGrams: Double  // Always in grams - LLM converts all units
    var price: Double
    var category: String

    enum CodingKeys: String, CodingKey {
        case name
        case quantityGrams = "quantity_grams"
        case price
        case category
    }
}

struct ExtractedNutrition: Codable {
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var saturatedFat: Double
    var sugar: Double
    var fiber: Double
    var sodium: Double
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

// MARK: - Protocol

protocol LLMService {
    /// Validate the API key by making a simple test request
    func validateAPIKey() async throws

    /// Extract items from a receipt image
    func extractReceiptItems(from image: UIImage) async throws -> [ExtractedReceiptItem]

    /// Extract items from receipt text (copy-pasted or typed)
    func extractReceiptItems(from text: String) async throws -> [ExtractedReceiptItem]

    /// Extract nutrition info from a nutrition label image
    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition

    /// Extract nutrition info from nutrition label text (copy-pasted or typed)
    func extractNutritionLabel(from text: String) async throws -> ExtractedNutrition

    /// Estimate nutrition for a food item by name
    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition

    /// Match receipt item to foods in the food bank
    func matchFood(itemName: String, existingFoods: [String]) async throws -> FoodMatch
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
