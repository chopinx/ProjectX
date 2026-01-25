import Foundation
import UIKit

final class OpenAIService: LLMService {
    private let apiKey: String
    private let model: OpenAIModel
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String, model: OpenAIModel = .gpt4o) {
        self.apiKey = apiKey
        self.model = model
    }

    func validateAPIKey() async throws {
        let body: [String: Any] = [
            "model": model.rawValue,
            "messages": [["role": "user", "content": "Hi"]],
            "max_tokens": 1
        ]
        _ = try await sendRequest(body: body)
    }

    func extractReceipt(from image: UIImage) async throws -> ExtractedReceipt {
        let response = try await sendVisionRequest(prompt: LLMPrompts.receiptImagePrompt, image: image)
        return try LLMJSONParser.parse(response, as: ExtractedReceipt.self)
    }

    func extractReceipt(from text: String) async throws -> ExtractedReceipt {
        let response = try await sendTextRequest(prompt: LLMPrompts.receiptTextPrompt(text))
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

    // MARK: - Private

    private func sendVisionRequest(prompt: String, image: UIImage) async throws -> String {
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        let body: [String: Any] = [
            "model": model.rawValue,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                ]
            ]],
            "max_tokens": 4096
        ]
        return try await sendRequest(body: body)
    }

    private func sendTextRequest(prompt: String) async throws -> String {
        let body: [String: Any] = [
            "model": model.rawValue,
            "messages": [["role": "user", "content": prompt]],
            "max_tokens": 1024
        ]
        return try await sendRequest(body: body)
    }

    private func sendRequest(body: [String: Any]) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 120

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw LLMError.networkError(NSError(domain: "LLM", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request cancelled"]))
        } catch {
            throw LLMError.networkError(error)
        }

        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        if http.statusCode == 401 { throw LLMError.invalidAPIKey }
        if http.statusCode == 429 { throw LLMError.rateLimited }
        guard http.statusCode == 200 else { throw LLMError.invalidResponse }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content
    }
}
