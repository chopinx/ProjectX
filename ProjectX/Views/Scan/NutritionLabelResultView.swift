import SwiftUI
import SwiftData

struct NutritionLabelResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let text: String
    let settings: AppSettings

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var extractedNutrition: ExtractedNutrition?
    @State private var foodName = ""
    @State private var category = FoodCategory(main: .other)
    @State private var showingSaveSuccess = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView().scaleEffect(1.5)
            } else if let error = errorMessage {
                errorView(error)
            } else if let nutrition = extractedNutrition {
                nutritionForm(nutrition)
            }
        }
        .navigationTitle("Nutrition Label")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "extract") {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await extractNutrition()
        }
        .alert("Saved!", isPresented: $showingSaveSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Food has been added to your Food Bank")
        }
    }

    private func errorView(_ error: String) -> some View {
        ErrorStateView("Extraction Failed", message: error) {
            Task { await extractNutrition() }
        }
        .padding()
    }

    private func nutritionForm(_ nutrition: ExtractedNutrition) -> some View {
        Form {
            Section("Food Details") {
                TextField("Food Name", text: $foodName)
                CategoryPicker(selection: $category)
            }
            Section("Extracted Nutrition (per 100g)") {
                LabeledContent("Calories", value: "\(Int(nutrition.calories)) kcal")
                LabeledContent("Protein", value: String(format: "%.1fg", nutrition.protein))
                LabeledContent("Carbohydrates", value: String(format: "%.1fg", nutrition.carbohydrates))
                LabeledContent("Fat", value: String(format: "%.1fg", nutrition.fat))
                LabeledContent("Saturated Fat", value: String(format: "%.1fg", nutrition.saturatedFat))
                LabeledContent("Sugar", value: String(format: "%.1fg", nutrition.sugar))
                LabeledContent("Fiber", value: String(format: "%.1fg", nutrition.fiber))
                LabeledContent("Sodium", value: String(format: "%.0fmg", nutrition.sodium))
            }
            Section {
                Button("Save to Food Bank") { saveFood(nutrition) }
                    .disabled(foodName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func extractNutrition() async {
        isLoading = true
        errorMessage = nil

        guard let service = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "Please configure your API key in Settings."
            isLoading = false
            return
        }

        do {
            extractedNutrition = try await service.extractNutritionLabel(from: text)
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func saveFood(_ nutrition: ExtractedNutrition) {
        let nutritionInfo = NutritionInfo(
            calories: nutrition.calories,
            protein: nutrition.protein,
            carbohydrates: nutrition.carbohydrates,
            fat: nutrition.fat,
            saturatedFat: nutrition.saturatedFat,
            sugar: nutrition.sugar,
            fiber: nutrition.fiber,
            sodium: nutrition.sodium
        )
        let food = Food(name: foodName, category: category, nutrition: nutritionInfo)
        context.insert(food)

        do {
            try context.save()
            showingSaveSuccess = true
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }
}
