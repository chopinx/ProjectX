import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

enum QuickAddMode: Int {
    case trip = 0
    case meal = 1
    case food = 2

    var title: String {
        switch self {
        case .trip: "Add Trip"
        case .meal: "Add Meal"
        case .food: "Add Food"
        }
    }

    var icon: String {
        switch self {
        case .trip: "cart"
        case .meal: "fork.knife.circle"
        case .food: "fork.knife"
        }
    }

    var hint: String {
        switch self {
        case .trip: "Add items to a new grocery trip"
        case .meal: "Log what you ate"
        case .food: "Add a new food to your library"
        }
    }
}

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]
    @Bindable var settings: AppSettings
    let mode: QuickAddMode
    let onScanPhoto: () -> Void
    let onTripItems: ((_ items: [PurchasedItem], _ storeName: String?, _ date: Date?) -> Void)?
    let onMealItems: ((_ items: [MealItem], _ date: Date?) -> Void)?
    let onFoodData: ((_ name: String, _ category: FoodCategory, _ nutrition: NutritionInfo?) -> Void)?

    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var errorMessage: String?
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    init(settings: AppSettings, mode: QuickAddMode, onScanPhoto: @escaping () -> Void,
         onTripItems: ((_ items: [PurchasedItem], _ storeName: String?, _ date: Date?) -> Void)? = nil,
         onMealItems: ((_ items: [MealItem], _ date: Date?) -> Void)? = nil,
         onFoodData: ((_ name: String, _ category: FoodCategory, _ nutrition: NutritionInfo?) -> Void)? = nil) {
        self._settings = Bindable(wrappedValue: settings)
        self.mode = mode
        self.onScanPhoto = onScanPhoto
        self.onTripItems = onTripItems
        self.onMealItems = onMealItems
        self.onFoodData = onFoodData
    }

    var body: some View {
        VStack(spacing: 16) {
            header.padding(.top, 16)
            actionButtons.padding(.bottom, 24)
        }
        .frame(height: 220)
        .background(Color(.systemGroupedBackground))
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 5, matching: .images)
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: false) { result in
            handleFileImport(result)
        }
        .onChange(of: selectedPhotos) { _, newItems in
            Task { await processSelectedPhotos(newItems) }
        }
        .overlay { if isProcessing { AIProcessingOverlay(message: processingMessage) } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Text(mode.title)
                    .font(.headline)
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .foregroundStyle(Color.themePrimary)
                Text(mode.hint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 24) {
            ActionCircleButton(
                icon: "camera.fill",
                label: "Camera",
                color: Color(.tertiarySystemFill),
                iconColor: Color.themePrimary
            ) {
                dismiss()
                onScanPhoto()
            }

            HoldToSpeakButton(
                mode: mode,
                settings: settings,
                foods: foods,
                onProcessing: { message in
                    processingMessage = message
                    isProcessing = true
                },
                onComplete: { error in
                    isProcessing = false
                    if let error = error {
                        errorMessage = error
                    }
                },
                onTripItems: { items, storeName, date in
                    onTripItems?(items, storeName, date)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
                },
                onMealItems: { items, date in
                    onMealItems?(items, date)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
                },
                onFoodData: { name, category, nutrition in
                    onFoodData?(name, category, nutrition)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
                }
            )

            Menu {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Import from Photos", systemImage: "photo.on.rectangle")
                }
                Button {
                    showingFilePicker = true
                } label: {
                    Label("Import from Files", systemImage: "doc.badge.plus")
                }
            } label: {
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color(.tertiarySystemFill))
                        .frame(width: 56, height: 56)
                        .overlay {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(Color.themePrimary)
                        }
                    Text("More")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Dispatch Helper

    /// Dispatch extracted receipt to the appropriate callback based on mode
    private func dispatchReceipt(_ receipt: ExtractedReceipt, service: LLMService) async {
        guard !receipt.items.isEmpty else {
            errorMessage = "Couldn't identify any items"
            return
        }
        switch mode {
        case .trip:
            onTripItems?(ItemMapper.mapToTripItems(receipt.items, foods: foods), receipt.storeName, receipt.parsedDate)
            dismiss()
        case .meal:
            onMealItems?(ItemMapper.mapToMealItems(receipt.items, foods: foods), receipt.parsedDate)
            dismiss()
        case .food:
            if let first = receipt.items.first {
                do {
                    let (name, category, nutrition) = try await ItemMapper.prepareFoodData(from: first.name, service: service)
                    onFoodData?(name, category, nutrition)
                    dismiss()
                } catch {
                    errorMessage = "Failed to process food: \(error.localizedDescription)"
                }
            }
        }
    }

    private func dispatchNutrition(_ nutrition: ExtractedNutrition) {
        let nutritionInfo = NutritionInfo(from: nutrition, source: .labelScan)
        onFoodData?(ItemMapper.extractedFoodName(from: nutrition), .other, nutritionInfo)
        dismiss()
    }

    // MARK: - Actions

    private func processSelectedPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isProcessing = true
        processingMessage = "Processing photos..."
        defer {
            isProcessing = false
            selectedPhotos = []
        }

        guard let service = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "Please configure your API key in Settings"
            return
        }

        var mergedReceipt = ExtractedReceipt(storeName: nil, receiptDate: nil, items: [])
        var failedCount = 0
        var loadFailedCount = 0

        for (index, item) in items.enumerated() {
            processingMessage = "Processing photo \(index + 1)/\(items.count)..."
            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    loadFailedCount += 1
                    continue
                }
                let receipt: ExtractedReceipt
                if mode == .meal {
                    receipt = try await service.extractMealItems(from: image, filterBabyFood: false)
                } else {
                    receipt = try await service.extractReceipt(from: image, filterBabyFood: settings.filterBabyFood)
                }
                mergedReceipt.items.append(contentsOf: receipt.items)
                if mergedReceipt.storeName == nil { mergedReceipt.storeName = receipt.storeName }
                if mergedReceipt.receiptDate == nil { mergedReceipt.receiptDate = receipt.receiptDate }
            } catch {
                failedCount += 1
            }
        }

        let totalFailed = failedCount + loadFailedCount
        if mergedReceipt.items.isEmpty {
            errorMessage = totalFailed > 0
                ? "Failed to process \(totalFailed) photo\(totalFailed == 1 ? "" : "s")"
                : "Couldn't identify any items"
            return
        }

        await dispatchReceipt(mergedReceipt, service: service)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await processFile(url) }
        case .failure(let error):
            errorMessage = "Failed to import file: \(error.localizedDescription)"
        }
    }

    private func processFile(_ url: URL) async {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access file"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        isProcessing = true
        processingMessage = "Processing file..."
        defer { isProcessing = false }

        guard let service = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "Please configure your API key in Settings"
            return
        }

        do {
            let ext = url.pathExtension.lowercased()

            if ext == "pdf" {
                guard let pdfData = try? Data(contentsOf: url) else {
                    errorMessage = "Failed to read PDF file"
                    return
                }
                if mode == .food {
                    dispatchNutrition(try await service.extractNutritionLabel(fromPDF: pdfData))
                } else {
                    let filterBaby = mode == .meal ? false : settings.filterBabyFood
                    let receipt = try await service.extractReceipt(fromPDF: pdfData, filterBabyFood: filterBaby)
                    await dispatchReceipt(receipt, service: service)
                }
                return
            }

            guard ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) else {
                errorMessage = "Unsupported file type"
                return
            }

            guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else {
                errorMessage = "Failed to read image file"
                return
            }

            if mode == .food {
                dispatchNutrition(try await service.extractNutritionLabel(from: img))
            } else if mode == .meal {
                let receipt = try await service.extractMealItems(from: img, filterBabyFood: false)
                await dispatchReceipt(receipt, service: service)
            } else {
                let receipt = try await service.extractReceipt(from: img, filterBabyFood: settings.filterBabyFood)
                await dispatchReceipt(receipt, service: service)
            }
        } catch {
            errorMessage = "Failed to process: \(error.localizedDescription)"
        }
    }
}

// MARK: - Action Circle Button

private struct ActionCircleButton: View {
    let icon: String
    let label: String
    let color: Color
    let iconColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

