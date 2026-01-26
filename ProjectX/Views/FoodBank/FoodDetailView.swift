import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var name: String
    @State private var category: FoodCategory
    @State private var selectedTags: [Tag]
    @State private var isPantryStaple: Bool
    @State private var nutrition: NutritionFields
    @State private var showingSaveError = false
    @State private var isAISuggestingCategory = false
    @State private var isAIEstimatingNutrition = false
    @State private var aiError: String?
    @State private var settings = AppSettings()
    @State private var hasAutoSuggested = false

    private var existingFood: Food?
    private var onSave: ((Food) -> Void)?
    private var autoSuggest: Bool

    /// Standard init for Food Bank (edit existing or create new)
    init(food: Food?) {
        self.existingFood = food
        self.onSave = nil
        self.autoSuggest = false
        _name = State(initialValue: food?.name ?? "")
        _category = State(initialValue: food?.category ?? .other)
        _selectedTags = State(initialValue: food?.tags ?? [])
        _isPantryStaple = State(initialValue: food?.isPantryStaple ?? false)
        _nutrition = State(initialValue: NutritionFields(from: food?.nutrition))
    }

    /// Init for creating new food with suggested values (used in receipt flow)
    init(suggestedName: String, suggestedCategory: String, onSave: @escaping (Food) -> Void) {
        self.existingFood = nil
        self.onSave = onSave
        self.autoSuggest = true
        _name = State(initialValue: suggestedName)
        _category = State(initialValue: FoodCategory(fromString: suggestedCategory))
        _selectedTags = State(initialValue: [])
        _isPantryStaple = State(initialValue: false)
        _nutrition = State(initialValue: NutritionFields())
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
                CategoryPicker(selection: $category)
                Toggle(isOn: $isPantryStaple) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pantry Staple")
                        Text("Long-lasting items like salt, oil, spices").font(.caption).foregroundStyle(.secondary)
                    }
                }
                aiCategoryButton
            }

            TagPicker(selectedTags: $selectedTags)

            Section {
                aiNutritionButton
            }
            NutritionFormSection(fields: $nutrition)
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
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: {
            Text("Failed to save changes. Please try again.")
        }
        .alert("AI Error", isPresented: .constant(aiError != nil)) {
            Button("OK") { aiError = nil }
        } message: {
            Text(aiError ?? "")
        }
        .task {
            if autoSuggest && !hasAutoSuggested && !name.isEmpty {
                hasAutoSuggested = true
                await suggestCategoryAndTags()
            }
        }
    }

    // MARK: - AI Category & Tags Button

    private var aiCategoryButton: some View {
        AIActionButton(
            title: "AI Suggest Category & Tags",
            loadingText: "Suggesting...",
            isLoading: isAISuggestingCategory,
            isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty || !settings.isConfigured
        ) {
            Task { await suggestCategoryAndTags() }
        }
    }

    private func suggestCategoryAndTags() async {
        await runAIOperation(setLoading: { isAISuggestingCategory = $0 }) { service in
            let suggestion = try await service.suggestCategoryAndTags(for: name, availableTags: allTags.map(\.name))
            if let main = FoodMainCategory(rawValue: suggestion.category) {
                let sub = suggestion.subcategory.flatMap { s in main.subcategories.first { $0.rawValue == s } }
                category = FoodCategory(main: main, sub: sub)
            }
            selectedTags = allTags.filter { suggestion.tags.contains($0.name) }
        }
    }

    // MARK: - AI Nutrition Button

    private var aiNutritionButton: some View {
        AIActionButton(
            title: "AI Estimate Nutrition",
            loadingText: "Estimating...",
            isLoading: isAIEstimatingNutrition,
            isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty || !settings.isConfigured
        ) {
            Task { await estimateNutrition() }
        }
    }

    private func estimateNutrition() async {
        await runAIOperation(setLoading: { isAIEstimatingNutrition = $0 }) { service in
            let result = try await service.estimateNutrition(for: name, category: category.displayName)
            nutrition.populate(from: result, source: .aiEstimate)
        }
    }

    private func runAIOperation(setLoading: (Bool) -> Void, operation: (LLMService) async throws -> Void) async {
        guard !name.isEmpty else { return }
        setLoading(true)
        aiError = nil
        guard let service = LLMServiceFactory.create(settings: settings) else {
            aiError = "Please configure your API key in Settings."
            setLoading(false)
            return
        }
        do {
            try await operation(service)
        } catch let error as LLMError {
            aiError = error.errorDescription
        } catch {
            aiError = error.localizedDescription
        }
        setLoading(false)
    }

    private func save() {
        let nutritionInfo = nutrition.toNutritionInfo()

        if let food = existingFood {
            food.name = name
            food.category = category
            food.tags = selectedTags
            food.isPantryStaple = isPantryStaple
            food.nutrition = nutritionInfo
            food.updatedAt = .now
        } else {
            let food = Food(name: name, category: category, nutrition: nutritionInfo, tags: selectedTags, isPantryStaple: isPantryStaple)
            context.insert(food)

            do {
                try context.save()
                if let onSave = onSave {
                    onSave(food)
                    return
                }
            } catch {
                showingSaveError = true
                return
            }
        }

        do {
            try context.save()
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}
