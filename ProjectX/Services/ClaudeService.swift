import Foundation
import UIKit

final class ClaudeService: LLMTransport {
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

    // Claude supports native PDF via its document API
    func extractReceipt(fromPDF data: Data, filterBabyFood: Bool) async throws -> ExtractedReceipt {
        let response = try await sendPDFRequest(prompt: LLMPrompts.receiptImagePrompt(filterBabyFood: filterBabyFood), pdfData: data)
        return try LLMJSONParser.parse(response, as: ExtractedReceipt.self)
    }

    func extractNutritionLabel(fromPDF data: Data) async throws -> ExtractedNutrition {
        let response = try await sendPDFRequest(prompt: LLMPrompts.nutritionLabelImagePrompt, pdfData: data)
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    // MARK: - LLMTransport

    func sendVisionRequest(prompt: String, image: UIImage) async throws -> String {
        let augmentedPrompt = await OCRService.augmentPrompt(prompt, withImage: image)
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        return try await sendDocumentRequest(prompt: augmentedPrompt, base64: base64, mediaType: "image/jpeg")
    }

    func sendPDFRequest(prompt: String, pdfData: Data) async throws -> String {
        let augmentedPrompt = await OCRService.augmentPrompt(prompt, withPDF: pdfData)
        let base64 = pdfData.base64EncodedString()
        return try await sendDocumentRequest(prompt: augmentedPrompt, base64: base64, mediaType: "application/pdf")
    }

    func sendTextRequest(prompt: String, maxTokens: Int = 1024) async throws -> String {
        let body: [String: Any] = [
            "model": model.rawValue,
            "max_tokens": maxTokens,
            "messages": [["role": "user", "content": prompt]]
        ]
        return try await sendRequest(body: body)
    }

    // MARK: - Private

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
        guard http.statusCode == 200 else { throw LLMError.serverError(statusCode: http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw LLMError.invalidResponse
        }
        return text
    }
}
