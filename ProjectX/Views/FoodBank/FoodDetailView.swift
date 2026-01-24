import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String
    @State private var category: FoodCategory
    @State private var selectedTags: [Tag]
    @State private var calories: String
    @State private var protein: String
    @State private var carbohydrates: String
    @State private var fat: String
    @State private var saturatedFat: String
    @State private var sugar: String
    @State private var fiber: String
    @State private var sodium: String
    @State private var showingSaveError = false

    private var existingFood: Food?

    init(food: Food?) {
        self.existingFood = food
        _name = State(initialValue: food?.name ?? "")
        _category = State(initialValue: food?.category ?? .other)
        _selectedTags = State(initialValue: food?.tags ?? [])
        _calories = State(initialValue: Self.format(food?.nutrition?.calories))
        _protein = State(initialValue: Self.format(food?.nutrition?.protein))
        _carbohydrates = State(initialValue: Self.format(food?.nutrition?.carbohydrates))
        _fat = State(initialValue: Self.format(food?.nutrition?.fat))
        _saturatedFat = State(initialValue: Self.format(food?.nutrition?.saturatedFat))
        _sugar = State(initialValue: Self.format(food?.nutrition?.sugar))
        _fiber = State(initialValue: Self.format(food?.nutrition?.fiber))
        _sodium = State(initialValue: Self.format(food?.nutrition?.sodium))
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
                CategoryPicker(selection: $category)
            }

            TagPicker(selectedTags: $selectedTags)

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
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: {
            Text("Failed to save changes. Please try again.")
        }
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
            food.tags = selectedTags
            food.nutrition = nutrition
            food.updatedAt = .now
        } else {
            let food = Food(name: name, category: category, nutrition: nutrition, tags: selectedTags)
            context.insert(food)
        }

        do {
            try context.save()
            dismiss()
        } catch {
            showingSaveError = true
        }
    }

    private static func format(_ value: Double?) -> String {
        guard let value, value != 0 else { return "" }
        return String(format: "%.1f", value)
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
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}
