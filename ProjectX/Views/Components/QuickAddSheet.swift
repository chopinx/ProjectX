import SwiftUI
import SwiftData
import Speech
import AVFoundation
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
        .overlay {
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView().tint(.white)
                        Text(processingMessage).font(.subheadline).foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
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
                    dismiss()
                },
                onMealItems: { items, date in
                    onMealItems?(items, date)
                    dismiss()
                },
                onFoodData: { name, category, nutrition in
                    onFoodData?(name, category, nutrition)
                    dismiss()
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
            onTripItems?(mapToTripItems(receipt.items, foods: foods), receipt.storeName, receipt.parsedDate)
            dismiss()
        case .meal:
            onMealItems?(mapToMealItems(receipt.items, foods: foods), receipt.parsedDate)
            dismiss()
        case .food:
            if let first = receipt.items.first {
                do {
                    let (name, category, nutrition) = try await prepareFoodData(from: first.name, service: service)
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
        onFoodData?(extractedFoodName(from: nutrition), .other, nutritionInfo)
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
                let receipt = try await service.extractReceipt(from: image, filterBabyFood: settings.filterBabyFood)
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
                    let receipt = try await service.extractReceipt(fromPDF: pdfData, filterBabyFood: settings.filterBabyFood)
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

// MARK: - Hold to Speak Button

private struct HoldToSpeakButton: View {
    let mode: QuickAddMode
    let settings: AppSettings
    let foods: [Food]
    let onProcessing: (String) -> Void
    let onComplete: (String?) -> Void
    let onTripItems: ((_ items: [PurchasedItem], _ storeName: String?, _ date: Date?) -> Void)?
    let onMealItems: ((_ items: [MealItem], _ date: Date?) -> Void)?
    let onFoodData: ((_ name: String, _ category: FoodCategory, _ nutrition: NutritionInfo?) -> Void)?

    @State private var isRecording = false
    @State private var permissionDenied = false
    @State private var permissionChecked = false
    @State private var transcribedText = ""
    @GestureState private var isPressed = false

    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine: AVAudioEngine?

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(isRecording ? Color.red : Color.themePrimary)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, isActive: isRecording)
                }
                .shadow(color: (isRecording ? Color.red : Color.themePrimary).opacity(0.4), radius: 8, y: 4)
                .scaleEffect(isPressed ? 1.1 : 1.0)
                .animation(.spring(response: 0.3), value: isPressed)
                .gesture(
                    LongPressGesture(minimumDuration: 0.1)
                        .updating($isPressed) { value, state, _ in
                            state = value
                        }
                        .onChanged { _ in
                            if !isRecording { startRecording() }
                        }
                        .onEnded { _ in
                            stopRecordingAndProcess()
                        }
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            if isRecording { stopRecordingAndProcess() }
                        }
                )
                .disabled(permissionDenied)
                .onAppear { checkPermissions() }
                .onDisappear { stopRecording() }

            Text(isRecording ? "Release" : "Hold to speak")
                .font(.caption)
                .foregroundStyle(isRecording ? .red : .secondary)
        }
    }

    private func checkPermissions() {
        guard !permissionChecked else { return }

        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status != .authorized { permissionDenied = true }
                permissionChecked = true
            }
        }

        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            await MainActor.run {
                if !granted { permissionDenied = true }
            }
        }
    }

    private func startRecording() {
        transcribedText = ""

        if speechRecognizer == nil {
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
        if audioEngine == nil {
            audioEngine = AVAudioEngine()
        }

        guard let recognizer = speechRecognizer, recognizer.isAvailable,
              let engine = audioEngine else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { return }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do { try engine.start() } catch { return }
        isRecording = true

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            Task { @MainActor in
                if let result = result {
                    transcribedText = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    stopRecording()
                }
            }
        }
    }

    private func stopRecording() {
        guard isRecording else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func stopRecordingAndProcess() {
        stopRecording()

        let textToProcess = transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToProcess.isEmpty else { return }

        Task {
            await processVoiceInput(textToProcess)
        }
    }

    private func processVoiceInput(_ text: String) async {
        guard settings.isConfigured else {
            onComplete("Please configure your API key in Settings first")
            return
        }

        onProcessing("Processing...")

        guard let service = LLMServiceFactory.create(settings: settings) else {
            onComplete("Failed to create AI service")
            return
        }

        do {
            switch mode {
            case .trip, .meal:
                let receipt = try await service.extractReceipt(from: text, filterBabyFood: settings.filterBabyFood)
                guard !receipt.items.isEmpty else {
                    onComplete("Couldn't identify any items")
                    return
                }
                onComplete(nil)
                if mode == .trip {
                    onTripItems?(mapToTripItems(receipt.items, foods: foods), receipt.storeName, receipt.parsedDate)
                } else {
                    onMealItems?(mapToMealItems(receipt.items, foods: foods), receipt.parsedDate)
                }

            case .food:
                let (foodName, category, nutrition) = try await prepareFoodData(from: text, service: service)
                onComplete(nil)
                onFoodData?(foodName, category, nutrition)
            }
        } catch {
            onComplete("Failed to process: \(error.localizedDescription)")
        }
    }
}

// MARK: - Shared Helpers

/// Extract the food name from an ExtractedNutrition, falling back to "Scanned Food"
func extractedFoodName(from nutrition: ExtractedNutrition) -> String {
    if let name = nutrition.foodName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
        return name
    }
    return "Scanned Food"
}

/// Find the best matching food for an item name using local string matching
func findMatchingFood(for itemName: String, in foods: [Food]) -> Food? {
    let nameLower = itemName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    guard !nameLower.isEmpty else { return nil }

    // Exact match
    if let food = foods.first(where: { $0.name.lowercased() == nameLower }) {
        return food
    }

    // Best substring match with length-ratio threshold
    var bestMatch: (food: Food, score: Double)?
    for food in foods {
        let foodLower = food.name.lowercased()
        if nameLower.contains(foodLower) || foodLower.contains(nameLower) {
            let shorter = Double(min(nameLower.count, foodLower.count))
            let longer = Double(max(nameLower.count, foodLower.count))
            let score = shorter / longer
            if score > (bestMatch?.score ?? 0) {
                bestMatch = (food, score)
            }
        }
    }

    return bestMatch?.score ?? 0 >= 0.6 ? bestMatch?.food : nil
}

func mapToTripItems(_ extracted: [ExtractedReceiptItem], foods: [Food]) -> [PurchasedItem] {
    extracted.map { item in
        let linkedFood = findMatchingFood(for: item.name, in: foods)
        return PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: linkedFood)
    }
}

func mapToMealItems(_ extracted: [ExtractedReceiptItem], foods: [Food]) -> [MealItem] {
    extracted.map { item in
        let linkedFood = findMatchingFood(for: item.name, in: foods)
        return MealItem(name: item.name, quantity: item.quantityGrams, food: linkedFood)
    }
}

private func prepareFoodData(from text: String, service: LLMService) async throws -> (String, FoodCategory, NutritionInfo?) {
    let foodName = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let suggestion = try await service.suggestCategoryAndTags(for: foodName, availableTags: [])
    let nutrition = try await service.estimateNutrition(for: foodName, category: suggestion.category)

    var category = FoodCategory.other
    if let main = FoodMainCategory(rawValue: suggestion.category) {
        let sub = suggestion.subcategory.flatMap { s in main.subcategories.first { $0.rawValue == s } }
        category = FoodCategory(main: main, sub: sub)
    }

    let nutritionInfo = NutritionInfo(from: nutrition, source: .aiEstimate)
    return (foodName, category, nutritionInfo)
}
