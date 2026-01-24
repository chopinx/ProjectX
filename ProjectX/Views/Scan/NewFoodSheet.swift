import SwiftUI
import SwiftData

enum NutritionSource: String, CaseIterable, Identifiable {
    case aiEstimate = "AI Estimate"
    case scanLabel = "Scan Label"
    case manual = "Manual Entry"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .aiEstimate: return "sparkles"
        case .scanLabel: return "camera.viewfinder"
        case .manual: return "square.and.pencil"
        }
    }
    var description: String {
        switch self {
        case .aiEstimate: return "Let AI estimate nutrition based on food name"
        case .scanLabel: return "Scan the nutrition label from packaging"
        case .manual: return "Enter nutrition values manually"
        }
    }
}

struct NewFoodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let suggestedName: String
    let suggestedCategory: String
    let onSave: (Food) -> Void

    @State private var name: String
    @State private var category: FoodCategory
    @State private var nutritionSource: NutritionSource = .aiEstimate
    @State private var showNutritionEntry = false
    @State private var showLabelScanner = false

    @State private var calories = ""
    @State private var protein = ""
    @State private var carbohydrates = ""
    @State private var fat = ""
    @State private var saturatedFat = ""
    @State private var sugar = ""
    @State private var fiber = ""
    @State private var sodium = ""

    @State private var isEstimating = false
    @State private var estimationError: String?
    @State private var settings = AppSettings()

    init(suggestedName: String, suggestedCategory: String, onSave: @escaping (Food) -> Void) {
        self.suggestedName = suggestedName
        self.suggestedCategory = suggestedCategory
        self.onSave = onSave
        _name = State(initialValue: suggestedName)
        _category = State(initialValue: FoodCategory(fromString: suggestedCategory))
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
                CategoryPicker(selection: $category)
            }

            Section("Nutrition Source") {
                ForEach(NutritionSource.allCases) { source in
                    Button {
                        nutritionSource = source
                        handleSourceSelection(source)
                    } label: {
                        HStack {
                            Image(systemName: source.icon)
                                .frame(width: 24)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.rawValue).font(.headline)
                                Text(source.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if nutritionSource == source {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            if showNutritionEntry || !calories.isEmpty {
                Section("Nutrition per 100g") {
                    NutritionFieldRow(label: "Calories", value: $calories, unit: "kcal")
                    NutritionFieldRow(label: "Protein", value: $protein, unit: "g")
                    NutritionFieldRow(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                    NutritionFieldRow(label: "Fat", value: $fat, unit: "g")
                    NutritionFieldRow(label: "Saturated Fat", value: $saturatedFat, unit: "g")
                    NutritionFieldRow(label: "Sugar", value: $sugar, unit: "g")
                    NutritionFieldRow(label: "Fiber", value: $fiber, unit: "g")
                    NutritionFieldRow(label: "Sodium", value: $sodium, unit: "mg")
                }
            }

            if isEstimating {
                Section {
                    HStack {
                        ProgressView()
                        Text("Estimating nutrition...")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let error = estimationError {
                Section {
                    Text(error).foregroundStyle(.red).font(.caption)
                }
            }
        }
        .navigationTitle("New Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveFood)
                    .disabled(name.isEmpty || isEstimating)
            }
        }
        .fullScreenCover(isPresented: $showLabelScanner) {
            NavigationStack {
                NutritionLabelScanView { nutrition in
                    populateNutrition(from: nutrition)
                    showLabelScanner = false
                    showNutritionEntry = true
                }
            }
        }
    }

    private func handleSourceSelection(_ source: NutritionSource) {
        switch source {
        case .aiEstimate: Task { await estimateNutrition() }
        case .scanLabel: showLabelScanner = true
        case .manual: showNutritionEntry = true
        }
    }

    private func estimateNutrition() async {
        guard !name.isEmpty else { return }

        isEstimating = true
        estimationError = nil

        guard let service = LLMServiceFactory.create(settings: settings) else {
            estimationError = "Please configure your API key in Settings."
            isEstimating = false
            return
        }

        do {
            let nutrition = try await service.estimateNutrition(for: name, category: category.displayName)
            populateNutrition(from: nutrition)
            showNutritionEntry = true
        } catch let error as LLMError {
            estimationError = error.errorDescription
        } catch {
            estimationError = "Failed to estimate nutrition: \(error.localizedDescription)"
        }
        isEstimating = false
    }

    private func populateNutrition(from nutrition: ExtractedNutrition) {
        calories = String(format: "%.1f", nutrition.calories)
        protein = String(format: "%.1f", nutrition.protein)
        carbohydrates = String(format: "%.1f", nutrition.carbohydrates)
        fat = String(format: "%.1f", nutrition.fat)
        saturatedFat = String(format: "%.1f", nutrition.saturatedFat)
        sugar = String(format: "%.1f", nutrition.sugar)
        fiber = String(format: "%.1f", nutrition.fiber)
        sodium = String(format: "%.1f", nutrition.sodium)
    }

    private func saveFood() {
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

        do {
            try context.save()
            onSave(food)
        } catch {
            dismiss()
        }
    }
}
