import SwiftUI
import SwiftData

enum NutritionLabelSource {
    case image(UIImage)
    case text(String)
    case pdf(Data)
}

struct NutritionLabelResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let source: NutritionLabelSource
    let settings: AppSettings

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var extractedNutrition: ExtractedNutrition?
    @State private var foodName = ""
    @State private var category = FoodCategory(main: .other)
    @State private var showingSaveSuccess = false

    init(image: UIImage, settings: AppSettings) {
        self.source = .image(image)
        self.settings = settings
    }

    init(text: String, settings: AppSettings) {
        self.source = .text(text)
        self.settings = settings
    }

    init(pdfData: Data, settings: AppSettings) {
        self.source = .pdf(pdfData)
        self.settings = settings
    }

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(message: "Extracting nutrition info...")
            } else if let error = errorMessage {
                errorView(error)
            } else if let nutrition = extractedNutrition {
                nutritionForm(nutrition)
            }
        }
        .navigationTitle("Nutrition Label")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: { Image(systemName: "xmark").fontWeight(.medium) }
            }
        }
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
            Section("Macronutrients (per 100g)") {
                LabeledContent("Calories", value: "\(Int(nutrition.calories)) kcal")
                LabeledContent("Protein", value: String(format: "%.1fg", nutrition.protein))
                LabeledContent("Carbohydrates", value: String(format: "%.1fg", nutrition.carbohydrates))
                LabeledContent("Sugar", value: String(format: "%.1fg", nutrition.sugar))
                LabeledContent("Fiber", value: String(format: "%.1fg", nutrition.fiber))
                LabeledContent("Fat", value: String(format: "%.1fg", nutrition.fat))
                LabeledContent("Saturated Fat", value: String(format: "%.1fg", nutrition.saturatedFat))
                LabeledContent("Omega-3", value: String(format: "%.1fg", nutrition.omega3))
                LabeledContent("Omega-6", value: String(format: "%.1fg", nutrition.omega6))
                LabeledContent("Sodium", value: String(format: "%.0fmg", nutrition.sodium))
            }
            Section("Micronutrients (per 100g)") {
                LabeledContent("Vitamin A", value: String(format: "%.0f mcg", nutrition.vitaminA))
                LabeledContent("Vitamin C", value: String(format: "%.1f mg", nutrition.vitaminC))
                LabeledContent("Vitamin D", value: String(format: "%.1f mcg", nutrition.vitaminD))
                LabeledContent("Calcium", value: String(format: "%.0f mg", nutrition.calcium))
                LabeledContent("Iron", value: String(format: "%.1f mg", nutrition.iron))
                LabeledContent("Potassium", value: String(format: "%.0f mg", nutrition.potassium))
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
            switch source {
            case .image(let image):
                extractedNutrition = try await service.extractNutritionLabel(from: image)
            case .text(let text):
                extractedNutrition = try await service.extractNutritionLabel(from: text)
            case .pdf(let data):
                extractedNutrition = try await service.extractNutritionLabel(fromPDF: data)
            }
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func saveFood(_ nutrition: ExtractedNutrition) {
        let nutritionInfo = NutritionInfo(from: nutrition, source: .labelScan)
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
