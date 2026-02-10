import Foundation
import UIKit

// MARK: - Response Types

struct ExtractedReceipt: Decodable {
    var storeName: String?
    var receiptDate: String?  // Date string from receipt (e.g., "2025-01-25" or "Jan 25, 2025")
    var items: [ExtractedReceiptItem]

    init(storeName: String? = nil, receiptDate: String? = nil, items: [ExtractedReceiptItem] = []) {
        self.storeName = storeName
        self.receiptDate = receiptDate
        self.items = items
    }

    private enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case receiptDate = "receipt_date"
        case items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // LLMs may return the string "null" instead of JSON null
        if let name = try? c.decodeIfPresent(String.self, forKey: .storeName),
           !name.isEmpty, name.lowercased() != "null" {
            storeName = name
        } else {
            storeName = nil
        }
        if let date = try? c.decodeIfPresent(String.self, forKey: .receiptDate),
           !date.isEmpty, date.lowercased() != "null" {
            receiptDate = date
        } else {
            receiptDate = nil
        }
        items = (try? c.decode([ExtractedReceiptItem].self, forKey: .items)) ?? []
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

struct ExtractedReceiptItem: Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantityGrams: Double  // Always in grams - LLM converts all units
    var price: Double
    var category: String
    var subcategory: String?
    var linkedFoodId: UUID?  // Auto-linked food ID if confidence is high enough
}

extension ExtractedReceiptItem: Codable {
    enum CodingKeys: String, CodingKey {
        case name
        case quantityGrams = "quantity_grams"
        case price
        case category
        case subcategory
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Unknown Item"
        quantityGrams = LLMDecoding.double(from: c, forKey: .quantityGrams)
        price = LLMDecoding.double(from: c, forKey: .price)
        let rawCategory = (try? c.decode(String.self, forKey: .category)) ?? "other"
        category = FoodMainCategory(rawValue: rawCategory) != nil ? rawCategory : "other"
        if let rawSub = try? c.decodeIfPresent(String.self, forKey: .subcategory) {
            subcategory = FoodSubcategory(rawValue: rawSub) != nil ? rawSub : nil
        } else {
            subcategory = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(quantityGrams, forKey: .quantityGrams)
        try c.encode(price, forKey: .price)
        try c.encode(category, forKey: .category)
        try c.encodeIfPresent(subcategory, forKey: .subcategory)
    }
}

struct ExtractedNutrition: Decodable {
    var foodName: String?  // Extracted from nutrition labels
    var calories, protein, carbohydrates, fat, saturatedFat: Double
    var omega3, omega6, sugar, fiber, sodium: Double
    var vitaminA, vitaminC, vitaminD, calcium, iron, potassium: Double

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        foodName = try? c.decodeIfPresent(String.self, forKey: .foodName)
        let d = { (key: CodingKeys) in LLMDecoding.double(from: c, forKey: key) }
        calories = d(.calories); protein = d(.protein); carbohydrates = d(.carbohydrates)
        fat = d(.fat); saturatedFat = d(.saturatedFat); omega3 = d(.omega3); omega6 = d(.omega6)
        sugar = d(.sugar); fiber = d(.fiber); sodium = d(.sodium)
        vitaminA = d(.vitaminA); vitaminC = d(.vitaminC); vitaminD = d(.vitaminD)
        calcium = d(.calcium); iron = d(.iron); potassium = d(.potassium)
    }

    private enum CodingKeys: String, CodingKey {
        case foodName = "food_name"
        case calories, protein, carbohydrates, fat, saturatedFat, omega3, omega6
        case sugar, fiber, sodium, vitaminA, vitaminC, vitaminD, calcium, iron, potassium
    }
}

struct FoodMatch: Identifiable {
    var id: UUID = UUID()
    var foodName: String?
    var confidence: Double
    var isNewFood: Bool
}

extension FoodMatch: Decodable {
    private enum CodingKeys: String, CodingKey {
        case foodName, confidence, isNewFood
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let name = try? c.decodeIfPresent(String.self, forKey: .foodName),
           name.lowercased() != "null" {
            foodName = name
        } else {
            foodName = nil
        }
        confidence = LLMDecoding.double(from: c, forKey: .confidence)
        if let v = try? c.decode(Bool.self, forKey: .isNewFood) {
            isNewFood = v
        } else if let s = try? c.decode(String.self, forKey: .isNewFood) {
            isNewFood = s.lowercased() == "true"
        } else {
            isNewFood = foodName == nil
        }
    }
}

struct SuggestedFoodInfo: Decodable {
    var category: String
    var subcategory: String?
    var tags: [String]

    private enum CodingKeys: String, CodingKey {
        case category, subcategory, tags
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawCategory = (try? c.decode(String.self, forKey: .category)) ?? "other"
        category = FoodMainCategory(rawValue: rawCategory) != nil ? rawCategory : "other"
        if let rawSub = try? c.decodeIfPresent(String.self, forKey: .subcategory) {
            subcategory = FoodSubcategory(rawValue: rawSub) != nil ? rawSub : nil
        } else {
            subcategory = nil
        }
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
    }
}

struct SuggestedNutritionTargets: Decodable {
    var calories, protein, carbohydrates, fat, saturatedFat: Double
    var omega3, omega6, sugar, fiber, sodium: Double
    var vitaminA, vitaminC, vitaminD, calcium, iron, potassium: Double
    var explanation: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let t = NutritionTarget.default
        let d = { (key: CodingKeys, def: Double) in LLMDecoding.double(from: c, forKey: key, default: def) }
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

    /// Extract items and store name from a PDF receipt
    func extractReceipt(fromPDF data: Data, filterBabyFood: Bool) async throws -> ExtractedReceipt

    /// Extract nutrition info from a nutrition label image
    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition

    /// Extract nutrition info from nutrition label text (copy-pasted or typed)
    func extractNutritionLabel(from text: String) async throws -> ExtractedNutrition

    /// Extract nutrition info from a PDF nutrition label
    func extractNutritionLabel(fromPDF data: Data) async throws -> ExtractedNutrition

    /// Estimate nutrition for a food item by name
    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition

    /// Estimate nutrition for empty fields, considering existing values
    func fillEmptyNutrition(
        for foodName: String,
        category: String,
        tags: [String],
        existingNutrition: [String: Double]
    ) async throws -> ExtractedNutrition

    /// Match receipt item to foods in the food bank
    func matchFood(itemName: String, existingFoods: [String]) async throws -> FoodMatch

    /// Suggest category and tags for a food item
    func suggestCategoryAndTags(for foodName: String, availableTags: [String]) async throws -> SuggestedFoodInfo

    /// Suggest daily nutrition targets based on family member profiles
    func suggestNutritionTargets(for members: [FamilyMember]) async throws -> SuggestedNutritionTargets
}

// MARK: - LLM Transport

/// Internal transport layer that each provider implements. Default LLMService
/// method implementations use these to avoid duplicating prompt→parse logic.
protocol LLMTransport: LLMService {
    func sendTextRequest(prompt: String, maxTokens: Int) async throws -> String
    func sendVisionRequest(prompt: String, image: UIImage) async throws -> String
    func sendPDFRequest(prompt: String, pdfData: Data) async throws -> String
}

extension LLMTransport {
    func sendTextRequest(prompt: String) async throws -> String {
        try await sendTextRequest(prompt: prompt, maxTokens: 1024)
    }

    func extractReceipt(from image: UIImage, filterBabyFood: Bool) async throws -> ExtractedReceipt {
        let response = try await sendVisionRequest(prompt: LLMPrompts.receiptImagePrompt(filterBabyFood: filterBabyFood), image: image)
        return try LLMJSONParser.parse(response, as: ExtractedReceipt.self)
    }

    func extractReceipt(from text: String, filterBabyFood: Bool) async throws -> ExtractedReceipt {
        let response = try await sendTextRequest(prompt: LLMPrompts.receiptTextPrompt(text, filterBabyFood: filterBabyFood), maxTokens: 4096)
        return try LLMJSONParser.parse(response, as: ExtractedReceipt.self)
    }

    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition {
        let response = try await sendVisionRequest(prompt: LLMPrompts.nutritionLabelImagePrompt, image: image)
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    func extractNutritionLabel(from text: String) async throws -> ExtractedNutrition {
        let response = try await sendTextRequest(prompt: LLMPrompts.nutritionLabelTextPrompt(text))
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition {
        let response = try await sendTextRequest(prompt: LLMPrompts.estimateNutritionPrompt(foodName: foodName, category: category))
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    func fillEmptyNutrition(for foodName: String, category: String, tags: [String], existingNutrition: [String: Double]) async throws -> ExtractedNutrition {
        let response = try await sendTextRequest(prompt: LLMPrompts.fillEmptyNutritionPrompt(foodName: foodName, category: category, tags: tags, existingNutrition: existingNutrition))
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    func matchFood(itemName: String, existingFoods: [String]) async throws -> FoodMatch {
        let response = try await sendTextRequest(prompt: LLMPrompts.matchFoodPrompt(itemName: itemName, existingFoods: existingFoods))
        return try LLMJSONParser.parse(response, as: FoodMatch.self)
    }

    func suggestCategoryAndTags(for foodName: String, availableTags: [String]) async throws -> SuggestedFoodInfo {
        let response = try await sendTextRequest(prompt: LLMPrompts.suggestCategoryAndTagsPrompt(foodName: foodName, availableTags: availableTags))
        return try LLMJSONParser.parse(response, as: SuggestedFoodInfo.self)
    }

    func suggestNutritionTargets(for members: [FamilyMember]) async throws -> SuggestedNutritionTargets {
        let response = try await sendTextRequest(prompt: LLMPrompts.suggestNutritionTargetsPrompt(members: members))
        return try LLMJSONParser.parse(response, as: SuggestedNutritionTargets.self)
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case serverError(statusCode: Int)
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
        case .serverError(let statusCode):
            return "AI service returned error (HTTP \(statusCode))."
        case .rateLimited:
            return "Rate limited. Please try again later."
        case .parseError(let message):
            return "Failed to parse response: \(message)"
        }
    }
}

// MARK: - Decoding Helpers

/// Helpers for decoding LLM responses that may return numbers as strings
enum LLMDecoding {
    /// Decode a Double that may be encoded as a string. Returns 0 if missing or unparseable.
    static func double<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K) -> Double {
        if let v = try? container.decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? container.decodeIfPresent(String.self, forKey: key), let v = Double(s) { return v }
        return 0
    }

    /// Decode a Double with a fallback default. Returns `defaultValue` if missing or unparseable.
    static func double<K: CodingKey>(from container: KeyedDecodingContainer<K>, forKey key: K, default defaultValue: Double) -> Double {
        if let v = try? container.decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? container.decodeIfPresent(String.self, forKey: key), let v = Double(s) { return v }
        return defaultValue
    }
}
