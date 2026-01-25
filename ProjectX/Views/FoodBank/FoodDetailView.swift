import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String
    @State private var category: FoodCategory
    @State private var selectedTags: [Tag]
    @State private var nutrition: NutritionFields
    @State private var showingSaveError = false

    private var existingFood: Food?

    init(food: Food?) {
        self.existingFood = food
        _name = State(initialValue: food?.name ?? "")
        _category = State(initialValue: food?.category ?? .other)
        _selectedTags = State(initialValue: food?.tags ?? [])
        _nutrition = State(initialValue: NutritionFields(from: food?.nutrition))
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
                CategoryPicker(selection: $category)
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
    }

    private func save() {
        let nutritionInfo = nutrition.toNutritionInfo()

        if let food = existingFood {
            food.name = name
            food.category = category
            food.tags = selectedTags
            food.nutrition = nutritionInfo
            food.updatedAt = .now
        } else {
            let food = Food(name: name, category: category, nutrition: nutritionInfo, tags: selectedTags)
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
