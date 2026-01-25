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

struct NutritionTarget: Codable, Equatable {
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var sugar: Double
    var fiber: Double
    var sodium: Double

    static let `default` = NutritionTarget(
        calories: 2000, protein: 50, carbohydrates: 250,
        fat: 65, sugar: 50, fiber: 25, sodium: 2300
    )

    static var zero: NutritionTarget {
        NutritionTarget(calories: 0, protein: 0, carbohydrates: 0, fat: 0, sugar: 0, fiber: 0, sodium: 0)
    }
}

@Observable
final class AppSettings {
    private let providerKey = "llm_provider"
    private let openaiKeyKey = "openai_api_key"
    private let claudeKeyKey = "claude_api_key"
    private let openaiModelKey = "openai_model"
    private let claudeModelKey = "claude_model"
    private let nutritionTargetKey = "nutrition_target"
    private let familyMembersKey = "family_members"
    private let familyGuideCompletedKey = "family_guide_completed"
    private let filterBabyFoodKey = "filter_baby_food"

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

    var dailyNutritionTarget: NutritionTarget {
        didSet {
            if let data = try? JSONEncoder().encode(dailyNutritionTarget) {
                UserDefaults.standard.set(data, forKey: nutritionTargetKey)
            }
        }
    }

    var familyMembers: [FamilyMember] {
        didSet {
            if let data = try? JSONEncoder().encode(familyMembers) {
                UserDefaults.standard.set(data, forKey: familyMembersKey)
            }
        }
    }

    var hasCompletedFamilyGuide: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedFamilyGuide, forKey: familyGuideCompletedKey)
        }
    }

    var filterBabyFood: Bool {
        didSet {
            UserDefaults.standard.set(filterBabyFood, forKey: filterBabyFoodKey)
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

        if let data = UserDefaults.standard.data(forKey: nutritionTargetKey),
           let target = try? JSONDecoder().decode(NutritionTarget.self, from: data) {
            self.dailyNutritionTarget = target
        } else {
            self.dailyNutritionTarget = .default
        }

        if let data = UserDefaults.standard.data(forKey: familyMembersKey),
           let members = try? JSONDecoder().decode([FamilyMember].self, from: data) {
            self.familyMembers = members
        } else {
            self.familyMembers = []
        }

        self.hasCompletedFamilyGuide = UserDefaults.standard.bool(forKey: familyGuideCompletedKey)
        self.filterBabyFood = UserDefaults.standard.bool(forKey: filterBabyFoodKey)
    }
}
