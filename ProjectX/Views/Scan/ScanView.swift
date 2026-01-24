import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ScanView: View {
    var settings: AppSettings
    @Environment(\.importManager) private var importManager

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showTextInput = false
    @State private var showScanTypeSelection = false

    @State private var capturedImage: UIImage?
    @State private var importedPDFData: Data?
    @State private var receiptText = ""

    @State private var showReviewFromText = false
    @State private var showNutritionFromText = false

    @State private var isProcessingOCR = false
    @State private var errorMessage: String?

    @State private var pendingOCRText: String?
    @State private var selectedScanType: ScanType?

    enum ScanType: String, CaseIterable, Identifiable {
        case receipt = "Receipt"
        case nutritionLabel = "Nutrition Label"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .receipt: return "doc.text.viewfinder"
            case .nutritionLabel: return "chart.bar.doc.horizontal"
            }
        }

        var description: String {
            switch self {
            case .receipt: return "Extract grocery items and prices"
            case .nutritionLabel: return "Extract nutrition information"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    Spacer()

                    if !settings.isConfigured {
                        configurationRequiredView
                    } else {
                        scanOptionsView
                    }

                    Spacer()
                }

                if isProcessingOCR {
                    ocrProcessingOverlay
                }
            }
            .navigationTitle("Scan")
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(
                    sourceType: .camera,
                    onImageCaptured: handleImageCaptured,
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                CameraView(
                    sourceType: .photoLibrary,
                    onImageCaptured: handleImageCaptured,
                    onCancel: { showPhotoPicker = false }
                )
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(allowedTypes: [.pdf, .image]) { url in
                    showDocumentPicker = false
                    handleDocumentPicked(url)
                }
            }
            .sheet(isPresented: $showTextInput) {
                ReceiptTextInputView(text: $receiptText) {
                    showTextInput = false
                    if !receiptText.isEmpty {
                        pendingOCRText = receiptText
                        showScanTypeSelection = true
                    }
                }
            }
            .sheet(isPresented: $showScanTypeSelection) {
                ScanTypeSelectionSheet(
                    onSelect: handleScanTypeSelected,
                    onCancel: {
                        showScanTypeSelection = false
                        pendingOCRText = nil
                    }
                )
                .presentationDetents([.medium])
            }
            .navigationDestination(isPresented: $showReviewFromText) {
                if let text = pendingOCRText {
                    ReceiptReviewView(text: text, settings: settings)
                }
            }
            .navigationDestination(isPresented: $showNutritionFromText) {
                if let text = pendingOCRText {
                    NutritionLabelFromTextView(text: text, settings: settings)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var configurationRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("API Key Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please configure your API key in Settings to enable scanning.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var scanOptionsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Scan Receipt or Label")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Take a photo, import a file, or enter text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Import PDF or Image", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    receiptText = ""
                    showTextInput = true
                } label: {
                    Label("Enter Text", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 48)
        }
    }

    private var ocrProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Extracting text...")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func handleImageCaptured(_ image: UIImage) {
        showCamera = false
        showPhotoPicker = false
        capturedImage = image

        Task {
            await performOCR(from: .image(image))
        }
    }

    private func handleDocumentPicked(_ url: URL) {
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            guard let data = try? Data(contentsOf: url) else {
                errorMessage = "Failed to read PDF file"
                return
            }
            Task {
                await performOCR(from: .pdf(data))
            }
        } else if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else {
                errorMessage = "Failed to read image file"
                return
            }
            Task {
                await performOCR(from: .image(image))
            }
        } else {
            errorMessage = "Unsupported file type"
        }
    }

    private func performOCR(from source: ImportManager.ImportSource) async {
        isProcessingOCR = true
        defer { isProcessingOCR = false }

        let manager = ImportManager()
        do {
            let text = try await manager.processImport(source)
            pendingOCRText = text
            showScanTypeSelection = true
        } catch {
            errorMessage = "Failed to extract text: \(error.localizedDescription)"
        }
    }

    private func handleScanTypeSelected(_ type: ScanType) {
        showScanTypeSelection = false
        selectedScanType = type

        switch type {
        case .receipt:
            showReviewFromText = true
        case .nutritionLabel:
            showNutritionFromText = true
        }
    }
}

// MARK: - Scan Type Selection Sheet

struct ScanTypeSelectionSheet: View {
    let onSelect: (ScanView.ScanType) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("What would you like to extract?")
                    .font(.headline)
                    .padding(.top)

                VStack(spacing: 16) {
                    ForEach(ScanView.ScanType.allCases) { type in
                        Button {
                            onSelect(type)
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: type.icon)
                                    .font(.title2)
                                    .frame(width: 40)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.rawValue)
                                        .font(.headline)
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Select Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}

// MARK: - Text Input View

struct ReceiptTextInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste or type your receipt/label text below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 200)

                Text("Example:\nApples 1kg 2.99\nMilk 1L 1.49\nBread 500g 2.29")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle("Enter Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") {
                        onSubmit()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Nutrition Label From Text View

struct NutritionLabelFromTextView: View {
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
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if let nutrition = extractedNutrition {
                resultView(nutrition)
            }
        }
        .navigationTitle("Nutrition Label")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await extractNutrition()
        }
        .alert("Saved!", isPresented: $showingSaveSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Food has been added to your Food Bank")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Extracting nutrition info...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Extraction Failed")
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task { await extractNutrition() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func resultView(_ nutrition: ExtractedNutrition) -> some View {
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
                Button("Save to Food Bank") {
                    saveFood(nutrition)
                }
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
            isLoading = false
        } catch let error as LLMError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            isLoading = false
        }
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

