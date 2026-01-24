import Foundation

enum LLMServiceFactory {
    static func create(settings: AppSettings) -> LLMService? {
        guard settings.isConfigured else { return nil }

        switch settings.selectedProvider {
        case .openai:
            return OpenAIService(apiKey: settings.openaiAPIKey, model: settings.selectedOpenAIModel)
        case .claude:
            return ClaudeService(apiKey: settings.claudeAPIKey, model: settings.selectedClaudeModel)
        }
    }
}
