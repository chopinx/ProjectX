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
    @State private var isAISuggesting = false
    @State private var aiError: String?
    @State private var settings = AppSettings()

    private var existingFood: Food?

    init(food: Food?) {
        self.existingFood = food
        _name = State(initialValue: food?.name ?? "")
        _category = State(initialValue: food?.category ?? .other)
        _selectedTags = State(initialValue: food?.tags ?? [])
        _isPantryStaple = State(initialValue: food?.isPantryStaple ?? false)
        _nutrition = State(initialValue: NutritionFields(from: food?.nutrition))
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
                aiSuggestButton
            }

            TagPicker(selectedTags: $selectedTags)

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
    }

    // MARK: - AI Suggest Button

    private var aiSuggestButton: some View {
        Button {
            Task { await suggestWithAI() }
        } label: {
            HStack {
                if isAISuggesting {
                    ProgressView().controlSize(.small)
                    Text("Suggesting...").foregroundStyle(.secondary)
                } else {
                    Label("AI Suggest Category & Tags", systemImage: "sparkles")
                }
            }
        }
        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isAISuggesting || !settings.isConfigured)
    }

    private func suggestWithAI() async {
        guard !name.isEmpty else { return }
        isAISuggesting = true
        aiError = nil

        guard let service = LLMServiceFactory.create(settings: settings) else {
            aiError = "Please configure your API key in Settings."
            isAISuggesting = false
            return
        }

        do {
            let tagNames = allTags.map(\.name)
            let suggestion = try await service.suggestCategoryAndTags(for: name, availableTags: tagNames)
            applySuggestion(suggestion)
        } catch let error as LLMError {
            aiError = error.errorDescription
        } catch {
            aiError = "Failed to get suggestion: \(error.localizedDescription)"
        }
        isAISuggesting = false
    }

    private func applySuggestion(_ suggestion: SuggestedFoodInfo) {
        // Apply category
        if let main = FoodMainCategory(rawValue: suggestion.category) {
            if let subRaw = suggestion.subcategory,
               let sub = main.subcategories.first(where: { $0.rawValue == subRaw }) {
                category = FoodCategory(main: main, sub: sub)
            } else {
                category = FoodCategory(main: main, sub: nil)
            }
        }

        // Apply tags
        let suggestedTags = allTags.filter { suggestion.tags.contains($0.name) }
        selectedTags = suggestedTags
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
        }

        do {
            try context.save()
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}
