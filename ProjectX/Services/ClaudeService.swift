import Foundation
import UIKit

final class ClaudeService: LLMService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-3-5-sonnet-20241022"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func extractReceiptItems(from image: UIImage) async throws -> [ExtractedReceiptItem] {
        let base64Image = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""

        let prompt = """
        Analyze this grocery receipt image and extract all food items.
        Translate any non-English text to English.

        Return a JSON array with this exact structure:
        [
          {
            "name": "English food name",
            "quantity_grams": 1000,
            "price": 2.99,
            "category": "produce/dairy/meat/seafood/bakery/beverages/snacks/frozen/pantry/other"
          }
        ]

        Rules:
        - Translate German/other languages to English
        - Convert ALL quantities to grams:
          - "1 kg" → 1000
          - "500 ml" → 500 (treat 1ml ≈ 1g)
          - "2 pcs" → estimate weight (e.g., "2 apples" → 360)
          - "1.5 L" → 1500
        - Price should be a number without currency symbol
        - Only return the JSON array, no other text
        """

        let response = try await sendVisionRequest(prompt: prompt, imageBase64: base64Image)
        return try parseJSON(response, as: [ExtractedReceiptItem].self)
    }

    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition {
        let base64Image = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""

        let prompt = """
        Extract nutrition information from this nutrition label image.
        Convert all values to per 100g.

        Return JSON with this exact structure:
        {
          "calories": 0,
          "protein": 0,
          "carbohydrates": 0,
          "fat": 0,
          "saturatedFat": 0,
          "sugar": 0,
          "fiber": 0,
          "sodium": 0
        }

        Rules:
        - All values per 100g
        - Calories in kcal
        - Protein, carbs, fat, saturatedFat, sugar, fiber in grams
        - Sodium in mg
        - If a value is not shown, estimate based on food type or use 0
        - Only return the JSON object, no other text
        """

        let response = try await sendVisionRequest(prompt: prompt, imageBase64: base64Image)
        return try parseJSON(response, as: ExtractedNutrition.self)
    }

    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition {
        let prompt = """
        Estimate typical nutrition values for: \(foodName) (category: \(category))

        Return JSON with this exact structure:
        {
          "calories": 0,
          "protein": 0,
          "carbohydrates": 0,
          "fat": 0,
          "saturatedFat": 0,
          "sugar": 0,
          "fiber": 0,
          "sodium": 0
        }

        Rules:
        - All values per 100g
        - Use typical/average values for this food
        - Calories in kcal
        - Protein, carbs, fat, saturatedFat, sugar, fiber in grams
        - Sodium in mg
        - Only return the JSON object, no other text
        """

        let response = try await sendTextRequest(prompt: prompt)
        return try parseJSON(response, as: ExtractedNutrition.self)
    }

    func matchFood(itemName: String, existingFoods: [String]) async throws -> FoodMatch {
        let foodList = existingFoods.joined(separator: "\n")

        let prompt = """
        Match this receipt item to the most similar food in the list.

        Receipt item: "\(itemName)"

        Existing foods:
        \(foodList.isEmpty ? "(empty list)" : foodList)

        Return JSON with this exact structure:
        {
          "foodName": "matched food name or null if no match",
          "confidence": 0.0 to 1.0,
          "isNewFood": true/false
        }

        Rules:
        - If confidence < 0.7, set isNewFood to true
        - If list is empty, set isNewFood to true
        - foodName should be null if isNewFood is true
        - Only return the JSON object, no other text
        """

        let response = try await sendTextRequest(prompt: prompt)
        return try parseJSON(response, as: FoodMatch.self)
    }

    // MARK: - Private Methods

    private func sendVisionRequest(prompt: String, imageBase64: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": imageBase64
                            ]
                        ],
                        ["type": "text", "text": prompt]
                    ]
                ]
            ]
        ]

        return try await sendRequest(body: body)
    }

    private func sendTextRequest(prompt: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        return try await sendRequest(body: body)
    }

    private func sendRequest(body: [String: Any]) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            throw LLMError.invalidAPIKey
        }

        if httpResponse.statusCode == 429 {
            throw LLMError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            throw LLMError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        return text
    }

    private func parseJSON<T: Decodable>(_ string: String, as type: T.Type) throws -> T {
        var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw LLMError.parseError("Invalid UTF-8 string")
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LLMError.parseError(error.localizedDescription)
        }
    }
}
