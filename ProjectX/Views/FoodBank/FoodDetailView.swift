import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Tag.name) private var allTags: [Tag]

    let settings: AppSettings
    @State private var name: String
    @State private var category: FoodCategory
    @State private var selectedTags: [Tag]
    @State private var isPantryStaple: Bool
    @State private var nutrition: NutritionFields
    @State private var showingSaveError = false
    @State private var isAISuggestingCategory = false
    @State private var isAIEstimatingNutrition = false
    @State private var aiError: String?
    @State private var hasAutoSuggested = false
    @State private var showingScanLabel = false

    private var existingFood: Food?
    private var onSave: ((Food) -> Void)?
    private var autoSuggest: Bool

    /// Standard init for Food Bank (edit existing or create new)
    init(food: Food?, settings: AppSettings) {
        self.existingFood = food
        self.settings = settings
        self.onSave = nil
        self.autoSuggest = false
        _name = State(initialValue: food?.name ?? "")
        _category = State(initialValue: food?.category ?? .other)
        _selectedTags = State(initialValue: food?.tags ?? [])
        _isPantryStaple = State(initialValue: food?.isPantryStaple ?? false)
        _nutrition = State(initialValue: NutritionFields(from: food?.nutrition))
    }

    /// Init for creating new food with suggested values (used in receipt flow)
    init(suggestedName: String, suggestedCategory: String, settings: AppSettings, onSave: @escaping (Food) -> Void) {
        self.existingFood = nil
        self.settings = settings
        self.onSave = onSave
        self.autoSuggest = true
        _name = State(initialValue: suggestedName)
        _category = State(initialValue: FoodCategory(fromString: suggestedCategory))
        _selectedTags = State(initialValue: [])
        _isPantryStaple = State(initialValue: false)
        _nutrition = State(initialValue: NutritionFields())
    }

    /// Init for creating new food with pre-populated nutrition (from scan or AI estimation)
    init(name: String, category: FoodCategory, nutrition: NutritionInfo?, settings: AppSettings) {
        self.existingFood = nil
        self.settings = settings
        self.onSave = nil
        self.autoSuggest = false
        _name = State(initialValue: name)
        _category = State(initialValue: category)
        _selectedTags = State(initialValue: [])
        _isPantryStaple = State(initialValue: false)
        _nutrition = State(initialValue: NutritionFields(from: nutrition))
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
                scanLabelButton
                aiNutritionButton
                resetNutritionButton
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
        .sheet(isPresented: $showingScanLabel) {
            NavigationStack {
                NutritionLabelScanView { extractedNutrition in
                    // Fill empty fields only from scanned nutrition label
                    nutrition.populateEmptyOnly(from: extractedNutrition, source: .labelScan)
                    showingScanLabel = false
                }
            }
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

    // MARK: - Scan Label Button

    private var scanLabelButton: some View {
        Button {
            showingScanLabel = true
        } label: {
            Label("Scan Nutrition Label", systemImage: "text.viewfinder")
        }
        .disabled(!settings.isConfigured)
    }

    // MARK: - AI Nutrition Button

    private var aiNutritionButton: some View {
        AIActionButton(
            title: "AI Fill Empty Fields",
            loadingText: "Estimating...",
            isLoading: isAIEstimatingNutrition,
            isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty || !settings.isConfigured
        ) {
            Task { await estimateNutrition(fillEmptyOnly: true) }
        }
    }

    private var resetNutritionButton: some View {
        Button {
            Task { await estimateNutrition(fillEmptyOnly: false) }
        } label: {
            HStack {
                if isAIEstimatingNutrition {
                    ProgressView().controlSize(.small)
                    Text("Estimating...").foregroundStyle(.secondary)
                } else {
                    Label("Reset All with AI", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || !settings.isConfigured || isAIEstimatingNutrition)
        .foregroundStyle(Color.themeWarning)
    }

    private func estimateNutrition(fillEmptyOnly: Bool) async {
        await runAIOperation(setLoading: { isAIEstimatingNutrition = $0 }) { service in
            if fillEmptyOnly {
                // Use context-aware fill that includes existing values
                let existingValues = nutrition.toExistingValuesDictionary()
                let tagNames = selectedTags.map(\.name)
                let result = try await service.fillEmptyNutrition(
                    for: name,
                    category: category.displayName,
                    tags: tagNames,
                    existingNutrition: existingValues
                )
                nutrition.populateEmptyOnly(from: result, source: .aiEstimate)
            } else {
                // Reset all fields first, then populate with basic estimate
                let result = try await service.estimateNutrition(for: name, category: category.displayName)
                nutrition = NutritionFields()
                nutrition.populate(from: result, source: .aiEstimate)
            }
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
