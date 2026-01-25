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
    @State private var nutrition = NutritionFields()
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
                    NutritionSourceButton(source: source, isSelected: nutritionSource == source) {
                        nutritionSource = source
                        handleSourceSelection(source)
                    }
                }
            }

            if showNutritionEntry || nutrition.hasValues {
                NutritionFormSection(fields: $nutrition)
            }

            if isEstimating {
                Section {
                    HStack {
                        ProgressView()
                        Text("Estimating nutrition...").foregroundStyle(.secondary)
                    }
                }
            }

            if let error = estimationError {
                Section { Text(error).foregroundStyle(Color.themeError).font(.caption) }
            }
        }
        .navigationTitle("New Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveFood).disabled(name.isEmpty || isEstimating)
            }
        }
        .fullScreenCover(isPresented: $showLabelScanner) {
            NavigationStack {
                NutritionLabelScanView { extracted in
                    nutrition.populate(from: extracted)
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
            let result = try await service.estimateNutrition(for: name, category: category.displayName)
            nutrition.populate(from: result)
            showNutritionEntry = true
        } catch let error as LLMError {
            estimationError = error.errorDescription
        } catch {
            estimationError = "Failed to estimate nutrition: \(error.localizedDescription)"
        }
        isEstimating = false
    }

    private func saveFood() {
        let food = Food(name: name, category: category, nutrition: nutrition.toNutritionInfo())
        context.insert(food)
        do {
            try context.save()
            onSave(food)
        } catch {
            dismiss()
        }
    }
}

// MARK: - Helpers

private struct NutritionSourceButton: View {
    let source: NutritionSource
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: source.icon).frame(width: 24).foregroundStyle(Color.themePrimary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.rawValue).font(.headline)
                    Text(source.description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themePrimary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

