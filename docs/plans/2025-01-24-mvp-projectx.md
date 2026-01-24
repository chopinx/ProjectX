# ProjectX MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an MVP diet management app that scans grocery receipts via LLM, extracts food items, maintains a household Food Bank with nutrition data, and shows nutrition summaries over time.

**Architecture:** Single iOS 17+ SwiftUI app using SwiftData for local persistence. LLM service abstraction supporting OpenAI and Claude APIs. Tab-based navigation: Home, Scan, Food Bank, Analysis, Settings.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, PhotosUI, XCTest, Xcode 15+, iOS 17 simulator.

---

## Alignment with PRD

- **Grams only:** All quantities stored in grams. LLM converts all units (kg, L, pcs) to grams.
- **Nutrition per 100g:** All nutrition values are per 100g, scaled by `quantity / 100`.
- **LLM Integration:** Receipt scanning, nutrition estimation, food matching.
- **Secure API Keys:** Stored in iOS Keychain.
- **Simplified Analysis:** MVP shows all-time and last-7-days summaries (charts deferred).

---

## Task 1: Domain Models & Nutrition Summary Logic

**Files:**
- Create: `ProjectX/Models/Food.swift`
- Create: `ProjectX/Models/GroceryTrip.swift`
- Create: `ProjectX/Models/NutritionSummary.swift`
- Modify: `ProjectX/Models/NutritionInfo.swift` (already exists)
- Modify: `ProjectX/Models/FoodCategory.swift` (already exists)
- Test: `ProjectXTests/Domain/NutritionSummaryTests.swift`

### Step 1: Verify existing models

Ensure `ProjectX/Models/FoodCategory.swift` exists with all categories.
Ensure `ProjectX/Models/NutritionInfo.swift` exists with `scaled(byGrams:)` method.

### Step 2: Create Food model

Create `ProjectX/Models/Food.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Food {
    var name: String
    var categoryRaw: String
    @Relationship(deleteRule: .cascade) var nutrition: NutritionInfo?
    var isUserCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String,
        category: FoodCategory = .other,
        nutrition: NutritionInfo? = nil,
        isUserCreated: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.nutrition = nutrition
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

### Step 3: Create GroceryTrip and PurchasedItem models

Create `ProjectX/Models/GroceryTrip.swift`:

```swift
import Foundation
import SwiftData

@Model
final class GroceryTrip {
    var date: Date
    var storeName: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PurchasedItem.trip)
    var items: [PurchasedItem] = []

    var totalSpent: Double {
        items.reduce(0) { $0 + $1.price }
    }

    init(
        date: Date = .now,
        storeName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.date = date
        self.storeName = storeName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PurchasedItem {
    var name: String
    var quantity: Double  // Always in grams (PRD requirement)
    var price: Double
    var food: Food?
    var trip: GroceryTrip?
    var isSkipped: Bool

    var calculatedNutrition: NutritionInfo? {
        food?.nutrition?.scaled(byGrams: quantity)
    }

    init(
        name: String,
        quantity: Double,
        price: Double,
        food: Food? = nil,
        isSkipped: Bool = false
    ) {
        self.name = name
        self.quantity = quantity
        self.price = price
        self.food = food
        self.isSkipped = isSkipped
    }
}
```

### Step 4: Create NutritionSummary

Create `ProjectX/Models/NutritionSummary.swift`:

```swift
import Foundation

struct NutritionSummary {
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbohydrates: Double
    var totalFat: Double
    var totalSaturatedFat: Double
    var totalSugar: Double
    var totalFiber: Double
    var totalSodium: Double

    static var zero: NutritionSummary {
        NutritionSummary(
            totalCalories: 0, totalProtein: 0, totalCarbohydrates: 0,
            totalFat: 0, totalSaturatedFat: 0, totalSugar: 0,
            totalFiber: 0, totalSodium: 0
        )
    }

    static func forTrips(_ trips: [GroceryTrip]) -> NutritionSummary {
        var summary = NutritionSummary.zero
        for trip in trips {
            for item in trip.items where !item.isSkipped {
                guard let nutrition = item.calculatedNutrition else { continue }
                summary.totalCalories += nutrition.calories
                summary.totalProtein += nutrition.protein
                summary.totalCarbohydrates += nutrition.carbohydrates
                summary.totalFat += nutrition.fat
                summary.totalSaturatedFat += nutrition.saturatedFat
                summary.totalSugar += nutrition.sugar
                summary.totalFiber += nutrition.fiber
                summary.totalSodium += nutrition.sodium
            }
        }
        return summary
    }
}
```

### Step 5: Run tests

```bash
xcodebuild test -project ProjectX.xcodeproj -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Step 6: Commit

```bash
git add ProjectX/Models ProjectXTests
git commit -m "feat: add domain models with grams-only quantity storage"
```

---

## Task 2: Keychain Helper & App Settings

**Files:**
- Create: `ProjectX/Utils/KeychainHelper.swift`
- Create: `ProjectX/Services/AppSettings.swift`

### Step 1: Create KeychainHelper

Create `ProjectX/Utils/KeychainHelper.swift`:

```swift
import Foundation
import Security

enum KeychainHelper {
    enum KeychainError: Error {
        case duplicateEntry
        case unknown(OSStatus)
        case itemNotFound
    }

    static func save(key: String, value: String) throws {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unknown(status)
        }
    }

    static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```

### Step 2: Create AppSettings

Create `ProjectX/Services/AppSettings.swift`:

```swift
import Foundation
import SwiftUI

enum LLMProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }
}

@Observable
final class AppSettings {
    private let providerKey = "llm_provider"
    private let openAIKeyKey = "openai_api_key"
    private let anthropicKeyKey = "anthropic_api_key"

    var selectedProvider: LLMProvider {
        didSet {
            UserDefaults.standard.set(selectedProvider.rawValue, forKey: providerKey)
        }
    }

    var openAIAPIKey: String {
        didSet {
            try? KeychainHelper.save(key: openAIKeyKey, value: openAIAPIKey)
        }
    }

    var anthropicAPIKey: String {
        didSet {
            try? KeychainHelper.save(key: anthropicKeyKey, value: anthropicAPIKey)
        }
    }

    var currentAPIKey: String {
        switch selectedProvider {
        case .openAI: return openAIAPIKey
        case .anthropic: return anthropicAPIKey
        }
    }

    var isConfigured: Bool {
        !currentAPIKey.isEmpty
    }

    init() {
        let providerRaw = UserDefaults.standard.string(forKey: providerKey) ?? LLMProvider.openAI.rawValue
        self.selectedProvider = LLMProvider(rawValue: providerRaw) ?? .openAI
        self.openAIAPIKey = KeychainHelper.get(key: openAIKeyKey) ?? ""
        self.anthropicAPIKey = KeychainHelper.get(key: anthropicKeyKey) ?? ""
    }
}
```

### Step 3: Commit

```bash
mkdir -p ProjectX/Utils ProjectX/Services
git add ProjectX/Utils ProjectX/Services/AppSettings.swift
git commit -m "feat: add KeychainHelper and AppSettings for secure API key storage"
```

---

## Task 3: LLM Service Layer

**Files:**
- Create: `ProjectX/Services/LLMService.swift`
- Create: `ProjectX/Services/OpenAIService.swift`
- Create: `ProjectX/Services/AnthropicService.swift`
- Create: `ProjectX/Services/LLMServiceFactory.swift`

### Step 1: Create LLMService protocol and types

Create `ProjectX/Services/LLMService.swift`:

```swift
import Foundation
import UIKit

// MARK: - Response Types

struct ExtractedReceiptItem: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var quantityGrams: Double
    var price: Double
    var category: String

    enum CodingKeys: String, CodingKey {
        case name
        case quantityGrams = "quantity_grams"
        case price
        case category
    }
}

struct ExtractedNutrition: Codable {
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var saturatedFat: Double
    var sugar: Double
    var fiber: Double
    var sodium: Double
}

// MARK: - Protocol

protocol LLMService {
    func extractReceiptItems(from image: UIImage) async throws -> [ExtractedReceiptItem]
    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition
    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "Invalid API key. Please check Settings."
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid response from AI service."
        case .rateLimited: return "Rate limited. Please try again later."
        case .parseError(let msg): return "Failed to parse response: \(msg)"
        }
    }
}

// MARK: - JSON Parsing Helper

enum LLMJSONParser {
    static func parse<T: Decodable>(_ string: String, as type: T.Type) throws -> T {
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
            throw LLMError.parseError("Invalid UTF-8")
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LLMError.parseError(error.localizedDescription)
        }
    }
}
```

### Step 2: Create OpenAI Service

Create `ProjectX/Services/OpenAIService.swift`:

```swift
import Foundation
import UIKit

final class OpenAIService: LLMService {
    private let apiKey: String
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func extractReceiptItems(from image: UIImage) async throws -> [ExtractedReceiptItem] {
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        let prompt = """
        Analyze this grocery receipt and extract all food items.
        Translate non-English text to English.

        Return JSON array:
        [{"name": "English name", "quantity_grams": 1000, "price": 2.99, "category": "produce"}]

        Rules:
        - Convert ALL quantities to grams: "1 kg"→1000, "500 ml"→500, "2 pcs apples"→360
        - Categories: produce, dairy, meat, seafood, bakery, beverages, snacks, frozen, pantry, other
        - Price as number without currency
        - Only return JSON array
        """
        let response = try await sendVisionRequest(prompt: prompt, imageBase64: base64)
        return try LLMJSONParser.parse(response, as: [ExtractedReceiptItem].self)
    }

    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition {
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        let prompt = """
        Extract nutrition from this label. Convert to per 100g.

        Return JSON:
        {"calories": 0, "protein": 0, "carbohydrates": 0, "fat": 0, "saturatedFat": 0, "sugar": 0, "fiber": 0, "sodium": 0}

        Rules: calories in kcal, protein/carbs/fat/sugar/fiber in g, sodium in mg. Only return JSON.
        """
        let response = try await sendVisionRequest(prompt: prompt, imageBase64: base64)
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition {
        let prompt = """
        Estimate typical nutrition per 100g for: \(foodName) (category: \(category))

        Return JSON:
        {"calories": 0, "protein": 0, "carbohydrates": 0, "fat": 0, "saturatedFat": 0, "sugar": 0, "fiber": 0, "sodium": 0}

        Use typical values. calories in kcal, sodium in mg, others in g. Only return JSON.
        """
        let response = try await sendTextRequest(prompt: prompt)
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    // MARK: - Private

    private func sendVisionRequest(prompt: String, imageBase64: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
                ]
            ]],
            "max_tokens": 4096
        ]
        return try await sendRequest(body: body)
    }

    private func sendTextRequest(prompt: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
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

        let (data, response) = try await URLSession.shared.data(for: request)
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
```

### Step 3: Create Anthropic Service

Create `ProjectX/Services/AnthropicService.swift`:

```swift
import Foundation
import UIKit

final class AnthropicService: LLMService {
    private let apiKey: String
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func extractReceiptItems(from image: UIImage) async throws -> [ExtractedReceiptItem] {
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        let prompt = """
        Analyze this grocery receipt and extract all food items.
        Translate non-English text to English.

        Return JSON array:
        [{"name": "English name", "quantity_grams": 1000, "price": 2.99, "category": "produce"}]

        Rules:
        - Convert ALL quantities to grams: "1 kg"→1000, "500 ml"→500, "2 pcs apples"→360
        - Categories: produce, dairy, meat, seafood, bakery, beverages, snacks, frozen, pantry, other
        - Price as number without currency
        - Only return JSON array
        """
        let response = try await sendVisionRequest(prompt: prompt, imageBase64: base64)
        return try LLMJSONParser.parse(response, as: [ExtractedReceiptItem].self)
    }

    func extractNutritionLabel(from image: UIImage) async throws -> ExtractedNutrition {
        let base64 = image.jpegData(compressionQuality: 0.8)?.base64EncodedString() ?? ""
        let prompt = """
        Extract nutrition from this label. Convert to per 100g.

        Return JSON:
        {"calories": 0, "protein": 0, "carbohydrates": 0, "fat": 0, "saturatedFat": 0, "sugar": 0, "fiber": 0, "sodium": 0}

        Rules: calories in kcal, protein/carbs/fat/sugar/fiber in g, sodium in mg. Only return JSON.
        """
        let response = try await sendVisionRequest(prompt: prompt, imageBase64: base64)
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    func estimateNutrition(for foodName: String, category: String) async throws -> ExtractedNutrition {
        let prompt = """
        Estimate typical nutrition per 100g for: \(foodName) (category: \(category))

        Return JSON:
        {"calories": 0, "protein": 0, "carbohydrates": 0, "fat": 0, "saturatedFat": 0, "sugar": 0, "fiber": 0, "sodium": 0}

        Use typical values. calories in kcal, sodium in mg, others in g. Only return JSON.
        """
        let response = try await sendTextRequest(prompt: prompt)
        return try LLMJSONParser.parse(response, as: ExtractedNutrition.self)
    }

    // MARK: - Private

    private func sendVisionRequest(prompt: String, imageBase64: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": imageBase64]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]
        return try await sendRequest(body: body)
    }

    private func sendTextRequest(prompt: String) async throws -> String {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "messages": [["role": "user", "content": prompt]]
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
```

### Step 4: Create LLM Service Factory

Create `ProjectX/Services/LLMServiceFactory.swift`:

```swift
import Foundation

enum LLMServiceFactory {
    static func create(settings: AppSettings) -> LLMService? {
        guard settings.isConfigured else { return nil }

        switch settings.selectedProvider {
        case .openAI:
            return OpenAIService(apiKey: settings.openAIAPIKey)
        case .anthropic:
            return AnthropicService(apiKey: settings.anthropicAPIKey)
        }
    }
}
```

### Step 5: Commit

```bash
git add ProjectX/Services
git commit -m "feat: add LLM service layer with OpenAI and Anthropic support"
```

---

## Task 4: Configure SwiftData & App Entry

**Files:**
- Modify: `ProjectX/ProjectXApp.swift`
- Modify: `ProjectX/ContentView.swift`

### Step 1: Update ProjectXApp

Replace `ProjectX/ProjectXApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct ProjectXApp: App {
    @State private var settings = AppSettings()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Food.self,
            NutritionInfo.self,
            GroceryTrip.self,
            PurchasedItem.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(settings: settings)
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### Step 2: Update ContentView

Replace `ProjectX/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            ScanView(settings: settings)
                .tabItem { Label("Scan", systemImage: "camera.viewfinder") }

            FoodBankView(settings: settings)
                .tabItem { Label("Food Bank", systemImage: "fork.knife") }

            AnalysisView()
                .tabItem { Label("Analysis", systemImage: "chart.bar.fill") }

            SettingsView(settings: settings)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}
```

### Step 3: Commit

```bash
git add ProjectX/ProjectXApp.swift ProjectX/ContentView.swift
git commit -m "feat: configure SwiftData and pass settings to views"
```

---

## Task 5: Food Bank UI with LLM Nutrition Estimation

**Files:**
- Create: `ProjectX/Views/FoodBank/FoodBankView.swift`
- Create: `ProjectX/Views/FoodBank/FoodDetailView.swift`

### Step 1: Create FoodBankView

Create `ProjectX/Views/FoodBank/FoodBankView.swift`:

```swift
import SwiftUI
import SwiftData

struct FoodBankView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]
    var settings: AppSettings

    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory?
    @State private var showingAddFood = false

    var filteredFoods: [Food] {
        var result = foods
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if foods.isEmpty {
                    ContentUnavailableView(
                        "No Foods Yet",
                        systemImage: "fork.knife",
                        description: Text("Tap + to add foods or scan a receipt")
                    )
                } else {
                    ForEach(filteredFoods) { food in
                        NavigationLink {
                            FoodDetailView(food: food, settings: settings)
                        } label: {
                            HStack {
                                Image(systemName: food.category.icon)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(food.name).font(.headline)
                                    if let n = food.nutrition {
                                        Text("\(Int(n.calories)) kcal per 100g")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteFoods)
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .navigationTitle("Food Bank")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All") { selectedCategory = nil }
                        Divider()
                        ForEach(FoodCategory.allCases) { cat in
                            Button { selectedCategory = cat } label: {
                                Label(cat.displayName, systemImage: cat.icon)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: selectedCategory == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddFood = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                NavigationStack {
                    FoodDetailView(food: nil, settings: settings)
                }
            }
        }
    }

    private func deleteFoods(at offsets: IndexSet) {
        for i in offsets { context.delete(filteredFoods[i]) }
        try? context.save()
    }
}
```

### Step 2: Create FoodDetailView with LLM estimation

Create `ProjectX/Views/FoodBank/FoodDetailView.swift`:

```swift
import SwiftUI
import SwiftData
import PhotosUI

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    var settings: AppSettings

    @State private var name: String
    @State private var category: FoodCategory
    @State private var calories: String
    @State private var protein: String
    @State private var carbohydrates: String
    @State private var fat: String
    @State private var saturatedFat: String
    @State private var sugar: String
    @State private var fiber: String
    @State private var sodium: String

    @State private var isEstimating = false
    @State private var isScanning = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

    private var existingFood: Food?

    init(food: Food?, settings: AppSettings) {
        self.existingFood = food
        self.settings = settings
        _name = State(initialValue: food?.name ?? "")
        _category = State(initialValue: food?.category ?? .other)
        _calories = State(initialValue: Self.fmt(food?.nutrition?.calories))
        _protein = State(initialValue: Self.fmt(food?.nutrition?.protein))
        _carbohydrates = State(initialValue: Self.fmt(food?.nutrition?.carbohydrates))
        _fat = State(initialValue: Self.fmt(food?.nutrition?.fat))
        _saturatedFat = State(initialValue: Self.fmt(food?.nutrition?.saturatedFat))
        _sugar = State(initialValue: Self.fmt(food?.nutrition?.sugar))
        _fiber = State(initialValue: Self.fmt(food?.nutrition?.fiber))
        _sodium = State(initialValue: Self.fmt(food?.nutrition?.sodium))
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(FoodCategory.allCases) { c in
                        Label(c.displayName, systemImage: c.icon).tag(c)
                    }
                }
            }

            if settings.isConfigured {
                Section {
                    Button {
                        Task { await estimateNutrition() }
                    } label: {
                        HStack {
                            Label("Get AI Estimate", systemImage: "sparkles")
                            if isEstimating { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isEstimating || name.isEmpty)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Label("Scan Nutrition Label", systemImage: "camera.viewfinder")
                            if isScanning { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isScanning)
                } footer: {
                    Text("Use AI to estimate or scan a product label")
                }
            }

            Section("Nutrition per 100g") {
                NutritionField(label: "Calories", value: $calories, unit: "kcal")
                NutritionField(label: "Protein", value: $protein, unit: "g")
                NutritionField(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                NutritionField(label: "Fat", value: $fat, unit: "g")
                NutritionField(label: "Saturated Fat", value: $saturatedFat, unit: "g")
                NutritionField(label: "Sugar", value: $sugar, unit: "g")
                NutritionField(label: "Fiber", value: $fiber, unit: "g")
                NutritionField(label: "Sodium", value: $sodium, unit: "mg")
            }
        }
        .navigationTitle(existingFood == nil ? "New Food" : "Edit Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onChange(of: selectedPhoto) { _, newValue in
            if newValue != nil { Task { await scanLabel() } }
        }
    }

    private func estimateNutrition() async {
        guard let llm = LLMServiceFactory.create(settings: settings) else { return }
        isEstimating = true
        defer { isEstimating = false }

        do {
            let n = try await llm.estimateNutrition(for: name, category: category.rawValue)
            applyNutrition(n)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scanLabel() async {
        guard let llm = LLMServiceFactory.create(settings: settings),
              let photo = selectedPhoto,
              let data = try? await photo.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Failed to load image"
            selectedPhoto = nil
            return
        }

        isScanning = true
        defer { isScanning = false; selectedPhoto = nil }

        do {
            let n = try await llm.extractNutritionLabel(from: image)
            applyNutrition(n)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applyNutrition(_ n: ExtractedNutrition) {
        calories = String(format: "%.1f", n.calories)
        protein = String(format: "%.1f", n.protein)
        carbohydrates = String(format: "%.1f", n.carbohydrates)
        fat = String(format: "%.1f", n.fat)
        saturatedFat = String(format: "%.1f", n.saturatedFat)
        sugar = String(format: "%.1f", n.sugar)
        fiber = String(format: "%.1f", n.fiber)
        sodium = String(format: "%.1f", n.sodium)
    }

    private func save() {
        let nutrition = NutritionInfo(
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbohydrates: Double(carbohydrates) ?? 0,
            fat: Double(fat) ?? 0,
            saturatedFat: Double(saturatedFat) ?? 0,
            sugar: Double(sugar) ?? 0,
            fiber: Double(fiber) ?? 0,
            sodium: Double(sodium) ?? 0
        )

        if let food = existingFood {
            food.name = name
            food.category = category
            food.nutrition = nutrition
            food.updatedAt = .now
        } else {
            context.insert(Food(name: name, category: category, nutrition: nutrition))
        }
        try? context.save()
        dismiss()
    }

    private static func fmt(_ v: Double?) -> String {
        guard let v, v != 0 else { return "" }
        return String(format: "%.1f", v)
    }
}

private struct NutritionField: View {
    let label: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit).foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
        }
    }
}
```

### Step 3: Commit

```bash
git add ProjectX/Views/FoodBank
git commit -m "feat: add Food Bank with LLM nutrition estimation and label scanning"
```

---

## Task 6: Receipt Scanning Flow

**Files:**
- Create: `ProjectX/Views/Scan/ScanView.swift`
- Create: `ProjectX/Views/Scan/ReceiptReviewView.swift`
- Create: `ProjectX/Views/Scan/NewFoodSheet.swift`

### Step 1: Create ScanView

Create `ProjectX/Views/Scan/ScanView.swift`:

```swift
import SwiftUI
import PhotosUI

struct ScanView: View {
    var settings: AppSettings

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var capturedImage: UIImage?
    @State private var showingCamera = false
    @State private var isProcessing = false
    @State private var extractedItems: [ExtractedReceiptItem] = []
    @State private var showingReview = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !settings.isConfigured {
                    ContentUnavailableView(
                        "API Key Required",
                        systemImage: "key.fill",
                        description: Text("Add your OpenAI or Anthropic API key in Settings")
                    )
                } else if isProcessing {
                    ProgressView("Analyzing receipt...")
                } else {
                    Spacer()
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                    Text("Scan a grocery receipt")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Spacer()

                    VStack(spacing: 16) {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Scan")
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $capturedImage)
            }
            .sheet(isPresented: $showingReview) {
                ReceiptReviewView(items: $extractedItems, settings: settings) {
                    showingReview = false
                    extractedItems = []
                }
            }
            .onChange(of: selectedPhoto) { _, val in
                Task {
                    if let data = try? await val?.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await processImage(img)
                    }
                }
            }
            .onChange(of: capturedImage) { _, img in
                if let img { Task { await processImage(img) } }
            }
        }
    }

    private func processImage(_ image: UIImage) async {
        guard let llm = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "LLM not configured"
            return
        }

        isProcessing = true
        defer { isProcessing = false; selectedPhoto = nil; capturedImage = nil }

        do {
            extractedItems = try await llm.extractReceiptItems(from: image)
            showingReview = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
```

### Step 2: Create ReceiptReviewView

Create `ProjectX/Views/Scan/ReceiptReviewView.swift`:

```swift
import SwiftUI
import SwiftData

struct ReceiptReviewView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var existingFoods: [Food]

    @Binding var items: [ExtractedReceiptItem]
    var settings: AppSettings
    var onComplete: () -> Void

    @State private var matchedFoods: [UUID: Food] = [:]
    @State private var skippedItems: Set<UUID> = []
    @State private var newFoodItem: ExtractedReceiptItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($items) { $item in
                        ItemRow(
                            item: item,
                            matchedFood: matchedFoods[item.id],
                            isSkipped: skippedItems.contains(item.id),
                            onToggleSkip: { toggleSkip(item) },
                            onAddFood: { newFoodItem = item },
                            onSelectFood: { food in matchedFoods[item.id] = food },
                            existingFoods: existingFoods
                        )
                    }
                    .onDelete { offsets in items.remove(atOffsets: offsets) }
                } header: {
                    Text("\(items.count) items extracted")
                }
            }
            .navigationTitle("Review Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss(); onComplete() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Trip") { saveTrip() }
                        .disabled(items.isEmpty)
                }
            }
            .sheet(item: $newFoodItem) { item in
                NewFoodSheet(item: item, settings: settings) { food in
                    matchedFoods[item.id] = food
                    newFoodItem = nil
                }
            }
            .onAppear { autoMatchFoods() }
        }
    }

    private func autoMatchFoods() {
        for item in items {
            if let match = existingFoods.first(where: {
                $0.name.localizedCaseInsensitiveContains(item.name) ||
                item.name.localizedCaseInsensitiveContains($0.name)
            }) {
                matchedFoods[item.id] = match
            }
        }
    }

    private func toggleSkip(_ item: ExtractedReceiptItem) {
        if skippedItems.contains(item.id) {
            skippedItems.remove(item.id)
        } else {
            skippedItems.insert(item.id)
        }
    }

    private func saveTrip() {
        let trip = GroceryTrip(date: .now)
        for item in items {
            let purchased = PurchasedItem(
                name: item.name,
                quantity: item.quantityGrams,
                price: item.price,
                food: matchedFoods[item.id],
                isSkipped: skippedItems.contains(item.id)
            )
            purchased.trip = trip
            trip.items.append(purchased)
        }
        context.insert(trip)
        try? context.save()
        dismiss()
        onComplete()
    }
}

private struct ItemRow: View {
    let item: ExtractedReceiptItem
    let matchedFood: Food?
    let isSkipped: Bool
    let onToggleSkip: () -> Void
    let onAddFood: () -> Void
    let onSelectFood: (Food) -> Void
    let existingFoods: [Food]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                        .strikethrough(isSkipped)
                        .foregroundStyle(isSkipped ? .secondary : .primary)
                    Text("\(Int(item.quantityGrams))g • \(String(format: "%.2f", item.price))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(isSkipped ? "Include" : "Skip") { onToggleSkip() }
                    .font(.caption)
                    .buttonStyle(.bordered)
            }

            if !isSkipped {
                if let food = matchedFood {
                    Label(food.name, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    HStack {
                        Menu {
                            ForEach(existingFoods) { food in
                                Button(food.name) { onSelectFood(food) }
                            }
                        } label: {
                            Label("Link Food", systemImage: "link")
                                .font(.caption)
                        }

                        Button { onAddFood() } label: {
                            Label("Add New", systemImage: "plus.circle")
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .opacity(isSkipped ? 0.6 : 1)
    }
}
```

### Step 3: Create NewFoodSheet

Create `ProjectX/Views/Scan/NewFoodSheet.swift`:

```swift
import SwiftUI
import SwiftData
import PhotosUI

struct NewFoodSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let item: ExtractedReceiptItem
    var settings: AppSettings
    var onSave: (Food) -> Void

    @State private var name: String
    @State private var category: FoodCategory
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var saturatedFat = ""
    @State private var sugar = ""
    @State private var fiber = ""
    @State private var sodium = ""

    @State private var isEstimating = false
    @State private var isScanning = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var errorMessage: String?

    init(item: ExtractedReceiptItem, settings: AppSettings, onSave: @escaping (Food) -> Void) {
        self.item = item
        self.settings = settings
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _category = State(initialValue: FoodCategory(rawValue: item.category) ?? .other)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(FoodCategory.allCases) { c in
                            Label(c.displayName, systemImage: c.icon).tag(c)
                        }
                    }
                }

                Section {
                    Button {
                        Task { await estimate() }
                    } label: {
                        HStack {
                            Label("Get AI Estimate", systemImage: "sparkles")
                            if isEstimating { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isEstimating || name.isEmpty)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Label("Scan Label", systemImage: "camera.viewfinder")
                            if isScanning { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isScanning)
                }

                Section("Nutrition per 100g") {
                    NutritionRow(label: "Calories", value: $calories, unit: "kcal")
                    NutritionRow(label: "Protein", value: $protein, unit: "g")
                    NutritionRow(label: "Carbs", value: $carbohydrates, unit: "g")
                    NutritionRow(label: "Fat", value: $fat, unit: "g")
                    NutritionRow(label: "Sat. Fat", value: $saturatedFat, unit: "g")
                    NutritionRow(label: "Sugar", value: $sugar, unit: "g")
                    NutritionRow(label: "Fiber", value: $fiber, unit: "g")
                    NutritionRow(label: "Sodium", value: $sodium, unit: "mg")
                }
            }
            .navigationTitle("New Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.isEmpty)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .onChange(of: selectedPhoto) { _, val in
                if val != nil { Task { await scan() } }
            }
        }
    }

    private func estimate() async {
        guard let llm = LLMServiceFactory.create(settings: settings) else { return }
        isEstimating = true
        defer { isEstimating = false }
        do {
            let n = try await llm.estimateNutrition(for: name, category: category.rawValue)
            apply(n)
        } catch { errorMessage = error.localizedDescription }
    }

    private func scan() async {
        guard let llm = LLMServiceFactory.create(settings: settings),
              let photo = selectedPhoto,
              let data = try? await photo.loadTransferable(type: Data.self),
              let img = UIImage(data: data) else {
            selectedPhoto = nil
            return
        }
        isScanning = true
        defer { isScanning = false; selectedPhoto = nil }
        do {
            let n = try await llm.extractNutritionLabel(from: img)
            apply(n)
        } catch { errorMessage = error.localizedDescription }
    }

    private func apply(_ n: ExtractedNutrition) {
        calories = String(format: "%.0f", n.calories)
        protein = String(format: "%.1f", n.protein)
        carbohydrates = String(format: "%.1f", n.carbohydrates)
        fat = String(format: "%.1f", n.fat)
        saturatedFat = String(format: "%.1f", n.saturatedFat)
        sugar = String(format: "%.1f", n.sugar)
        fiber = String(format: "%.1f", n.fiber)
        sodium = String(format: "%.0f", n.sodium)
    }

    private func save() {
        let nutrition = NutritionInfo(
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbohydrates: Double(carbohydrates) ?? 0,
            fat: Double(fat) ?? 0,
            saturatedFat: Double(saturatedFat) ?? 0,
            sugar: Double(sugar) ?? 0,
            fiber: Double(fiber) ?? 0,
            sodium: Double(sodium) ?? 0
        )
        let food = Food(name: name, category: category, nutrition: nutrition)
        context.insert(food)
        try? context.save()
        onSave(food)
        dismiss()
    }
}

private struct NutritionRow: View {
    let label: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 70)
            Text(unit).foregroundStyle(.secondary).frame(width: 35)
        }
    }
}
```

### Step 4: Commit

```bash
git add ProjectX/Views/Scan
git commit -m "feat: add receipt scanning with LLM extraction and review flow"
```

---

## Task 7: Home Tab & Analysis Tab

**Files:**
- Create: `ProjectX/Views/Home/HomeView.swift`
- Create: `ProjectX/Views/Home/TripDetailView.swift`
- Create: `ProjectX/Views/Analysis/AnalysisView.swift`

### Step 1: Create HomeView

Create `ProjectX/Views/Home/HomeView.swift`:

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \GroceryTrip.date, order: .reverse) private var trips: [GroceryTrip]

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "cart.badge.plus",
                        description: Text("Scan a receipt to get started")
                    )
                } else {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tripTitle(trip))
                                    .font(.headline)
                                HStack {
                                    Text("\(trip.items.count) items")
                                    Spacer()
                                    Text(String(format: "%.2f", trip.totalSpent))
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets { context.delete(trips[i]) }
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Home")
        }
    }

    private func tripTitle(_ trip: GroceryTrip) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        let date = fmt.string(from: trip.date)
        if let store = trip.storeName, !store.isEmpty {
            return "\(store) - \(date)"
        }
        return date
    }
}
```

### Step 2: Create TripDetailView

Create `ProjectX/Views/Home/TripDetailView.swift`:

```swift
import SwiftUI
import SwiftData

struct TripDetailView: View {
    let trip: GroceryTrip

    var body: some View {
        List {
            Section("Trip Info") {
                LabeledContent("Date", value: trip.date, format: .dateTime.day().month().year())
                if let store = trip.storeName {
                    LabeledContent("Store", value: store)
                }
                LabeledContent("Total", value: String(format: "%.2f", trip.totalSpent))
            }

            Section("Items (\(trip.items.count))") {
                ForEach(trip.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                                .font(.headline)
                                .strikethrough(item.isSkipped)
                                .foregroundStyle(item.isSkipped ? .secondary : .primary)
                            if let food = item.food {
                                Text(food.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(item.quantity))g")
                            Text(String(format: "%.2f", item.price))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }

            let summary = NutritionSummary.forTrips([trip])
            Section("Nutrition Total") {
                LabeledContent("Calories", value: "\(Int(summary.totalCalories)) kcal")
                LabeledContent("Protein", value: "\(Int(summary.totalProtein)) g")
                LabeledContent("Carbs", value: "\(Int(summary.totalCarbohydrates)) g")
                LabeledContent("Fat", value: "\(Int(summary.totalFat)) g")
            }
        }
        .navigationTitle("Trip Details")
    }
}
```

### Step 3: Create AnalysisView

Create `ProjectX/Views/Analysis/AnalysisView.swift`:

```swift
import SwiftUI
import SwiftData

struct AnalysisView: View {
    @Query(sort: \GroceryTrip.date) private var trips: [GroceryTrip]

    private var allTime: NutritionSummary { NutritionSummary.forTrips(trips) }

    private var last7Days: [GroceryTrip] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return trips.filter { $0.date >= cutoff }
    }

    private var last7Summary: NutritionSummary { NutritionSummary.forTrips(last7Days) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if trips.isEmpty {
                        ContentUnavailableView(
                            "No Data Yet",
                            systemImage: "chart.bar.doc.horizontal",
                            description: Text("Scan receipts to see nutrition analysis")
                        )
                        .padding(.top, 100)
                    } else {
                        SummaryCard(title: "Last 7 Days", summary: last7Summary, count: last7Days.count)
                        SummaryCard(title: "All Time", summary: allTime, count: trips.count)
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis")
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let summary: NutritionSummary
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(count) trip\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Stat(label: "Calories", value: "\(Int(summary.totalCalories))", unit: "kcal")
                Spacer()
                Stat(label: "Protein", value: "\(Int(summary.totalProtein))", unit: "g")
                Spacer()
                Stat(label: "Carbs", value: "\(Int(summary.totalCarbohydrates))", unit: "g")
                Spacer()
                Stat(label: "Fat", value: "\(Int(summary.totalFat))", unit: "g")
            }
            Divider()
            HStack {
                Mini(label: "Sat. Fat", value: summary.totalSaturatedFat)
                Mini(label: "Sugar", value: summary.totalSugar)
                Mini(label: "Fiber", value: summary.totalFiber)
                Mini(label: "Sodium", value: summary.totalSodium)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct Stat: View {
    let label, value, unit: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title2).fontWeight(.semibold)
            Text("\(label) (\(unit))").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct Mini: View {
    let label: String
    let value: Double
    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))").font(.subheadline).fontWeight(.medium)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

### Step 4: Commit

```bash
git add ProjectX/Views/Home ProjectX/Views/Analysis
git commit -m "feat: add Home and Analysis tabs"
```

---

## Task 8: Settings View

**Files:**
- Create: `ProjectX/Views/Settings/SettingsView.swift`

### Step 1: Create SettingsView

Create `ProjectX/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    @State private var showOpenAI = false
    @State private var showAnthropic = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $settings.selectedProvider) {
                        ForEach(LLMProvider.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("LLM Provider")
                }

                Section {
                    HStack {
                        Text("OpenAI")
                        Spacer()
                        if !settings.openAIAPIKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    HStack {
                        Group {
                            if showOpenAI {
                                TextField("sk-...", text: $settings.openAIAPIKey)
                            } else {
                                SecureField("sk-...", text: $settings.openAIAPIKey)
                            }
                        }
                        .textContentType(.password)
                        .autocorrectionDisabled()

                        Button { showOpenAI.toggle() } label: {
                            Image(systemName: showOpenAI ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }

                    HStack {
                        Text("Anthropic")
                        Spacer()
                        if !settings.anthropicAPIKey.isEmpty {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    HStack {
                        Group {
                            if showAnthropic {
                                TextField("sk-ant-...", text: $settings.anthropicAPIKey)
                            } else {
                                SecureField("sk-ant-...", text: $settings.anthropicAPIKey)
                            }
                        }
                        .textContentType(.password)
                        .autocorrectionDisabled()

                        Button { showAnthropic.toggle() } label: {
                            Image(systemName: showAnthropic ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("API Keys")
                } footer: {
                    Text("Keys are stored securely in iOS Keychain")
                }

                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        if settings.isConfigured {
                            Label("Ready", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Key required", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

### Step 2: Commit

```bash
git add ProjectX/Views/Settings
git commit -m "feat: add Settings with secure API key management"
```

---

## Task 9: Final Integration & QA

### Step 1: Build and test

```bash
xcodebuild build -project ProjectX.xcodeproj -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project ProjectX.xcodeproj -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Step 2: Manual QA checklist

- [ ] Settings: Add API key, verify stored in Keychain
- [ ] Settings: Switch providers, verify key association
- [ ] Scan: Take photo or select image
- [ ] Scan: Verify LLM extracts items with grams and prices
- [ ] Scan: Review items, skip/link/add new foods
- [ ] Scan: Save trip successfully
- [ ] Food Bank: Add food manually
- [ ] Food Bank: Use AI estimate for nutrition
- [ ] Food Bank: Scan nutrition label
- [ ] Food Bank: Edit and delete foods
- [ ] Home: View trips list
- [ ] Home: View trip details with nutrition
- [ ] Home: Delete trips
- [ ] Analysis: View 7-day and all-time summaries
- [ ] App persists data across launches

### Step 3: Final commit

```bash
git add .
git commit -m "feat: complete MVP with LLM integration"
```

---

## Summary

**MVP Features:**
1. SwiftData models: Food, NutritionInfo, GroceryTrip, PurchasedItem, Tag
2. All quantities in grams (LLM converts from kg/L/pcs)
3. LLM service layer: OpenAI + Claude support
4. Secure API key storage via Keychain with validation
5. Receipt scanning with AI extraction (image or text input)
6. Receipt review flow with food matching
7. Food Bank with AI nutrition estimation + label scanning
8. Nutrition analysis (7-day + all-time)
9. Two-level food category system (Main Category + Subcategory)
10. Tag system for food labeling with default tags
11. Default data management with restore functionality

**Files:** ~30 Swift files

**Use Cases Covered:**
| Use Case | Status |
|----------|--------|
| Scan receipt photo | Yes |
| Enter receipt text | Yes |
| LLM extracts items (translated, grams) | Yes |
| Review/edit extracted items | Yes |
| Link items to Food Bank | Yes |
| Add new food with AI estimate | Yes |
| Scan nutrition label (image or text) | Yes |
| Manual food entry | Yes |
| View grocery trips | Yes |
| View trip nutrition | Yes |
| View 7-day summary | Yes |
| View all-time summary | Yes |
| Secure API key storage | Yes |
| API key validation on save | Yes |
| Two-level food categories | Yes |
| Tag foods with custom labels | Yes |
| Filter by category/tag | Yes |
| Restore default tags | Yes |
| Export data (selective) | Yes |
| Import data (selective) | Yes |

---

## Recent Updates

### Food Category System (Simplified)

Two-level hierarchical category system focused on food types:

**Level 1 - Main Categories:**
- Vegetables, Fruits, Meat & Poultry, Seafood, Dairy & Eggs
- Grains & Bread, Legumes & Beans, Nuts & Seeds, Oils & Fats
- Snacks & Sweets, Beverages, Other

**Level 2 - Subcategories:**
- Each main category has relevant subcategories (e.g., Meat: Poultry, Red Meat, Processed Meat)
- Subcategory selection is optional

**Files:**
- `ProjectX/Models/FoodCategory.swift` - Category enums and FoodCategory struct
- `ProjectX/Views/Components/CategoryPicker.swift` - Hierarchical category picker UI

### Tag System

Flexible tagging system for food labeling:

**Features:**
- Create custom tags with name and color
- Attach multiple tags to any food
- Filter Food Bank by tags
- Default tags for common use cases (Organic, High Protein, Red Meat, etc.)

**Default Tags:**
- Organic, Local, High Protein, Low Carb, Plant-Based, Whole Food
- Processed, Red Meat, High Fiber, Omega-3 Rich, Low Sodium, Sugar-Free

**Files:**
- `ProjectX/Models/Tag.swift` - Tag model with color support
- `ProjectX/Views/Components/TagPicker.swift` - Tag selection/creation UI
- `ProjectX/Services/DefaultDataManager.swift` - Default data management

### Data Management

- Default tags created on first launch
- Restore default tags in Settings (Add Missing or Reset All)
- Proper error handling for all save operations
- Fixed orphaned item deletion when editing trips

### OCR & Import Features

**OCR Processing:**
- Uses Vision framework for on-device text extraction
- All images and PDFs go through OCR before LLM processing
- Supports both searchable and image-based PDFs
- Text extraction happens locally (no API calls needed)

**Import Options:**
- Take Photo (camera)
- Choose from Library (photo picker)
- Import PDF or Image (document picker)
- Enter Text manually
- Share from other apps (via URL handling)

**Scan Type Selection:**
- After OCR, user chooses: Receipt or Nutrition Label
- Receipt: Extracts grocery items with prices and quantities
- Nutrition Label: Extracts per-100g nutrition values

**Files:**
- `ProjectX/Services/OCRService.swift` - Vision-based text extraction
- `ProjectX/Services/ImportManager.swift` - Import handling and document picker
- Updated `ProjectX/Views/Scan/ScanView.swift` - New import flow with OCR

### Data Export/Import

Full data export and import functionality with selective data type support:

**Export Features:**
- Multi-select data types: Food Bank, Tags, Grocery Trips
- JSON format with ISO8601 dates
- Export via iOS Share Sheet
- Filename: `ProjectX-Export-YYYY-MM-DD.json`

**Import Features:**
- File picker for JSON imports
- Preview imported data before confirming
- Multi-select which data types to import
- Replace existing items with same name (not skip)
- Maintains food-tag relationships during import

**Unique Constraints:**
- `@Attribute(.unique)` on `Tag.name` and `Food.name` at model level
- UI validation prevents duplicate names when creating tags
- Import replaces existing items with matching names

**Files:**
- `ProjectX/Services/DataExportService.swift` - Export/import service with Codable structures
- Updated `ProjectX/Views/Settings/SettingsView.swift` - Export/import UI sheets

### Shared Components

Reusable UI components extracted for code simplification:

**Files:**
- `ProjectX/Views/Components/TextInputSheet.swift` - Shared text input sheet (receipt/nutrition label)
- `ProjectX/Views/Components/NutritionFieldRow.swift` - Nutrition input row component
