import Foundation

enum LLMServiceFactory {
    static func create(settings: AppSettings) -> LLMService? {
        guard settings.isConfigured else { return nil }

        switch settings.selectedProvider {
        case .openai:
            return OpenAIService(apiKey: settings.openaiAPIKey)
        case .claude:
            return ClaudeService(apiKey: settings.claudeAPIKey)
        }
    }
}
