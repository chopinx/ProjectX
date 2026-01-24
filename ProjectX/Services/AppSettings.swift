import Foundation
import SwiftUI

enum LLMProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case claude = "Claude"

    var id: String { rawValue }
}

@Observable
final class AppSettings {
    private let providerKey = "llm_provider"
    private let openaiKeyKey = "openai_api_key"
    private let claudeKeyKey = "claude_api_key"

    var selectedProvider: LLMProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: providerKey)
        }
    }

    var openaiAPIKey: String {
        didSet {
            try? KeychainHelper.save(key: openaiKeyKey, value: openaiAPIKey)
        }
    }

    var claudeAPIKey: String {
        didSet {
            try? KeychainHelper.save(key: claudeKeyKey, value: claudeAPIKey)
        }
    }

    var currentAPIKey: String {
        switch selectedProvider {
        case .openai: return openaiAPIKey
        case .claude: return claudeAPIKey
        }
    }

    var isConfigured: Bool {
        !currentAPIKey.isEmpty
    }

    init() {
        let providerRaw = UserDefaults.standard.string(forKey: providerKey) ?? LLMProvider.openai.rawValue
        self.selectedProvider = LLMProvider(rawValue: providerRaw) ?? .openai
        self.openaiAPIKey = KeychainHelper.get(key: openaiKeyKey) ?? ""
        self.claudeAPIKey = KeychainHelper.get(key: claudeKeyKey) ?? ""
    }
}
