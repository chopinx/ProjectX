import Foundation
import UIKit

final class OpenAIService: LLMTransport {
    private let apiKey: String
    private let model: OpenAIModel
    private let baseURL = "https://api.openai.com/v1/chat/completions"

    init(apiKey: String, model: OpenAIModel = .gpt5) {
        self.apiKey = apiKey
        self.model = model
    }

    func validateAPIKey() async throws {
        var body: [String: Any] = [
            "model": model.rawValue,
            "messages": [["role": "user", "content": "Hi"]]
        ]
        applyTokenLimit(1, to: &body)
        _ = try await sendRequest(body: body)
    }

    // OpenAI converts PDFs to images before sending
    func extractReceipt(fromPDF data: Data, filterBabyFood: Bool) async throws -> ExtractedReceipt {
        guard let image = PDFHelper.extractImage(from: data) else { throw LLMError.invalidResponse }
        return try await extractReceipt(from: image, filterBabyFood: filterBabyFood)
    }

    func extractNutritionLabel(fromPDF data: Data) async throws -> ExtractedNutrition {
        guard let image = PDFHelper.extractImage(from: data) else { throw LLMError.invalidResponse }
        return try await extractNutritionLabel(from: image)
    }

    // MARK: - LLMTransport

    func sendVisionRequest(prompt: String, image: UIImage) async throws -> String {
        let augmentedPrompt = await OCRService.augmentPrompt(prompt, withImage: image)
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        var body: [String: Any] = [
            "model": model.rawValue,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": augmentedPrompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64)"]]
                ]
            ]]
        ]
        applyTokenLimit(4096, to: &body)
        return try await sendRequest(body: body)
    }

    func sendPDFRequest(prompt: String, pdfData: Data) async throws -> String {
        // OpenAI doesn't support native PDF - convert to image first
        guard let image = PDFHelper.extractImage(from: pdfData) else { throw LLMError.invalidResponse }
        return try await sendVisionRequest(prompt: prompt, image: image)
    }

    func sendTextRequest(prompt: String, maxTokens: Int = 1024) async throws -> String {
        var body: [String: Any] = [
            "model": model.rawValue,
            "messages": [["role": "user", "content": prompt]]
        ]
        applyTokenLimit(maxTokens, to: &body)
        return try await sendRequest(body: body)
    }

    // MARK: - Private

    private func applyTokenLimit(_ tokens: Int, to body: inout [String: Any]) {
        if model.isReasoningModel {
            body["max_completion_tokens"] = tokens
        } else {
            body["max_tokens"] = tokens
        }
    }

    private func sendRequest(body: [String: Any]) async throws -> String {
        guard let url = URL(string: baseURL) else { throw LLMError.invalidResponse }
        var request = URLRequest(url: url)
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
        guard http.statusCode == 200 else { throw LLMError.serverError(statusCode: http.statusCode) }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }
        return content
    }
}
