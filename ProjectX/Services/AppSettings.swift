import Foundation
import SwiftUI

enum LLMProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case claude = "Claude"

    var id: String { rawValue }

    var availableModels: [LLMModel] {
        switch self {
        case .openai: return OpenAIModel.allCases.map { .openai($0) }
        case .claude: return ClaudeModel.allCases.map { .claude($0) }
        }
    }

    var defaultModel: LLMModel {
        switch self {
        case .openai: return .openai(.gpt4o)
        case .claude: return .claude(.sonnet4)
        }
    }
}

enum OpenAIModel: String, CaseIterable, Identifiable {
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt35Turbo = "gpt-3.5-turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o (Recommended)"
        case .gpt4oMini: return "GPT-4o Mini"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        }
    }

    var supportsVision: Bool {
        switch self {
        case .gpt4o, .gpt4oMini, .gpt4Turbo: return true
        case .gpt35Turbo: return false
        }
    }
}

enum ClaudeModel: String, CaseIterable, Identifiable {
    case sonnet4 = "claude-sonnet-4-20250514"
    case opus4 = "claude-opus-4-20250514"
    case haiku35 = "claude-3-5-haiku-20241022"
    case sonnet35 = "claude-3-5-sonnet-20241022"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sonnet4: return "Claude Sonnet 4 (Recommended)"
        case .opus4: return "Claude Opus 4"
        case .haiku35: return "Claude 3.5 Haiku"
        case .sonnet35: return "Claude 3.5 Sonnet"
        }
    }

    var supportsVision: Bool { true }
}

enum LLMModel: Equatable, Identifiable {
    case openai(OpenAIModel)
    case claude(ClaudeModel)

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .openai(let m): return m.rawValue
        case .claude(let m): return m.rawValue
        }
    }

    var displayName: String {
        switch self {
        case .openai(let m): return m.displayName
        case .claude(let m): return m.displayName
        }
    }

    var supportsVision: Bool {
        switch self {
        case .openai(let m): return m.supportsVision
        case .claude(let m): return m.supportsVision
        }
    }
}

@Observable
final class AppSettings {
    private let providerKey = "llm_provider"
    private let openaiKeyKey = "openai_api_key"
    private let claudeKeyKey = "claude_api_key"
    private let openaiModelKey = "openai_model"
    private let claudeModelKey = "claude_model"

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

    var selectedOpenAIModel: OpenAIModel {
        didSet {
            UserDefaults.standard.set(selectedOpenAIModel.rawValue, forKey: openaiModelKey)
        }
    }

    var selectedClaudeModel: ClaudeModel {
        didSet {
            UserDefaults.standard.set(selectedClaudeModel.rawValue, forKey: claudeModelKey)
        }
    }

    var currentAPIKey: String {
        switch selectedProvider {
        case .openai: return openaiAPIKey
        case .claude: return claudeAPIKey
        }
    }

    var currentModel: LLMModel {
        switch selectedProvider {
        case .openai: return .openai(selectedOpenAIModel)
        case .claude: return .claude(selectedClaudeModel)
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

        let openaiModelRaw = UserDefaults.standard.string(forKey: openaiModelKey) ?? OpenAIModel.gpt4o.rawValue
        self.selectedOpenAIModel = OpenAIModel(rawValue: openaiModelRaw) ?? .gpt4o

        let claudeModelRaw = UserDefaults.standard.string(forKey: claudeModelKey) ?? ClaudeModel.sonnet4.rawValue
        self.selectedClaudeModel = ClaudeModel(rawValue: claudeModelRaw) ?? .sonnet4
    }
}
