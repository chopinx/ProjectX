import Foundation
import UIKit

final class ClaudeService: LLMService {
    private let apiKey: String
    private let model: ClaudeModel
    private let baseURL = "https://api.anthropic.com/v1/messages"

    init(apiKey: String, model: ClaudeModel = .sonnet4) {
        self.apiKey = apiKey
        self.model = model
    }

    func validateAPIKey() async throws {
        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 1,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        _ = try await sendRequest(body: body)
    }

    func extractReceipt(from image: UIImage, filterBabyFood: Bool) async throws -> ExtractedReceipt {
        let response = try await sendVisionRequest(prompt: LLMPrompts.receiptImagePrompt(filterBabyFood: filterBabyFood), image: image)
        return try LLMJSONParser.parse(response, as: ExtractedReceipt.self)
    }

    func extractReceipt(from text: String, filterBabyFood: Bool) async throws -> ExtractedReceipt {
        let response = try await sendTextRequest(prompt: LLMPrompts.receiptTextPrompt(text, filterBabyFood: filterBabyFood))
        return try LLMJSONParser.parse(response, as: ExtractedReceipt.self)
    }

    func extractReceipt(fromPDF data: Data, filterBabyFood: Bool) async throws -> ExtractedReceipt {
        let response = try await sendPDFRequest(prompt: LLMPrompts.receiptImagePrompt(filterBabyFood: filterBabyFood), pdfData: data)
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

    func extractNutritionLabel(fromPDF data: Data) async throws -> ExtractedNutrition {
        let response = try await sendPDFRequest(prompt: LLMPrompts.nutritionLabelImagePrompt, pdfData: data)
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

    // MARK: - Private

    private func sendVisionRequest(prompt: String, image: UIImage) async throws -> String {
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        return try await sendDocumentRequest(prompt: prompt, base64: base64, mediaType: "image/jpeg")
    }

    private func sendPDFRequest(prompt: String, pdfData: Data) async throws -> String {
        let base64 = pdfData.base64EncodedString()
        return try await sendDocumentRequest(prompt: prompt, base64: base64, mediaType: "application/pdf")
    }

    private func sendDocumentRequest(prompt: String, base64: String, mediaType: String) async throws -> String {
        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 4096,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "document" as Any, "source": ["type": "base64", "media_type": mediaType, "data": base64]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]
        return try await sendRequest(body: body)
    }

    private func sendTextRequest(prompt: String) async throws -> String {
        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
        ]
        return try await sendRequest(body: body)
    }

    private func sendRequest(body: [String: Any]) async throws -> String {
        guard let url = URL(string: baseURL) else { throw LLMError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
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
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw LLMError.invalidResponse
        }
        return text
    }
}
