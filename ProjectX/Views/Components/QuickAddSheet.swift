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
    @Environment(\.modelContext) private var context
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(sort: \Food.name) private var foods: [Food]
    @Bindable var settings: AppSettings
    let mode: QuickAddMode
    let onScanPhoto: () -> Void

    @State private var isProcessing = false
    @State private var processingMessage = ""
    @State private var errorMessage: String?
    @State private var showingPhotoPicker = false
    @State private var showingFilePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []

    private var activeProfile: Profile? {
        profiles.first { $0.id == settings.activeProfileId }
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            header
                .padding(.top, 16)

            // Action buttons
            actionButtons
                .padding(.bottom, 24)
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
            // Camera button (left)
            ActionCircleButton(
                icon: "camera.fill",
                label: "Camera",
                color: Color(.tertiarySystemFill),
                iconColor: Color.themePrimary
            ) {
                dismiss()
                onScanPhoto()
            }

            // Mic button (center, primary)
            HoldToSpeakButton(
                mode: mode,
                settings: settings,
                context: context,
                foods: foods,
                activeProfile: activeProfile,
                onProcessing: { message in
                    processingMessage = message
                    isProcessing = true
                },
                onComplete: { error in
                    isProcessing = false
                    if let error = error {
                        errorMessage = error
                    } else {
                        dismiss()
                    }
                }
            )

            // More button (right) with menu
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

        var allItems: [ExtractedReceiptItem] = []
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
                allItems.append(contentsOf: receipt.items)
            } catch {
                failedCount += 1
            }
        }

        // Show error if all photos failed
        let totalFailed = failedCount + loadFailedCount
        if allItems.isEmpty {
            if totalFailed > 0 {
                errorMessage = "Failed to process \(totalFailed) photo\(totalFailed == 1 ? "" : "s")"
            } else {
                errorMessage = "Couldn't identify any items"
            }
            return
        }

        // Create trip or meal with extracted items
        switch mode {
        case .trip:
            createTrip(with: allItems)
        case .meal:
            createMeal(with: allItems)
        case .food:
            // For food mode, just create the first item as a food
            if let first = allItems.first {
                do {
                    try await createFood(from: first.name, service: service)
                } catch {
                    errorMessage = "Failed to create food: \(error.localizedDescription)"
                    return
                }
            }
        }

        do {
            try context.save()
            if totalFailed > 0 {
                errorMessage = "Added \(allItems.count) items. \(totalFailed) photo\(totalFailed == 1 ? "" : "s") failed."
            }
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
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
            var image: UIImage?

            if ext == "pdf" {
                guard let pdfData = try? Data(contentsOf: url) else {
                    errorMessage = "Failed to read PDF file"
                    return
                }
                image = extractImageFromPDF(pdfData)
            } else if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
                guard let data = try? Data(contentsOf: url) else {
                    errorMessage = "Failed to read image file"
                    return
                }
                image = UIImage(data: data)
            }

            guard let img = image else {
                errorMessage = "Unsupported file type"
                return
            }

            switch mode {
            case .trip:
                let receipt = try await service.extractReceipt(from: img, filterBabyFood: settings.filterBabyFood)
                guard !receipt.items.isEmpty else {
                    errorMessage = "Couldn't identify any items"
                    return
                }
                createTrip(with: receipt.items)

            case .meal:
                let receipt = try await service.extractReceipt(from: img, filterBabyFood: settings.filterBabyFood)
                guard !receipt.items.isEmpty else {
                    errorMessage = "Couldn't identify any food items"
                    return
                }
                createMeal(with: receipt.items)

            case .food:
                let nutrition = try await service.extractNutritionLabel(from: img)
                let nutritionInfo = NutritionInfo(from: nutrition, source: .labelScan)
                let food = Food(name: "Scanned Food", category: .other, nutrition: nutritionInfo, tags: [], isPantryStaple: false)
                context.insert(food)
            }

            try context.save()
            dismiss()
        } catch {
            errorMessage = "Failed to process: \(error.localizedDescription)"
        }
    }

    private func extractImageFromPDF(_ data: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdfDoc = CGPDFDocument(provider),
              let page = pdfDoc.page(at: 1) else { return nil }

        let pageRect = page.getBoxRect(.mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: scale, y: -scale)
        ctx.drawPDFPage(page)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }

    private func createTrip(with items: [ExtractedReceiptItem]) {
        let trip = GroceryTrip(date: .now)
        trip.profile = activeProfile
        context.insert(trip)

        for item in items {
            let linkedFood = item.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
            let purchasedItem = PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: linkedFood)
            purchasedItem.trip = trip
            trip.items.append(purchasedItem)
        }
    }

    private func createMeal(with items: [ExtractedReceiptItem]) {
        let meal = Meal(date: .now, mealType: suggestMealType())
        meal.profile = activeProfile
        context.insert(meal)

        for item in items {
            let linkedFood = item.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
            let mealItem = MealItem(name: item.name, quantity: item.quantityGrams, food: linkedFood)
            mealItem.meal = meal
            meal.items.append(mealItem)
        }
    }

    private func createFood(from text: String, service: LLMService) async throws {
        let foodName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = try await service.suggestCategoryAndTags(for: foodName, availableTags: [])
        let nutrition = try await service.estimateNutrition(for: foodName, category: suggestion.category)

        var category = FoodCategory.other
        if let main = FoodMainCategory(rawValue: suggestion.category) {
            let sub = suggestion.subcategory.flatMap { s in main.subcategories.first { $0.rawValue == s } }
            category = FoodCategory(main: main, sub: sub)
        }

        let nutritionInfo = NutritionInfo(from: nutrition, source: .aiEstimate)
        let food = Food(name: foodName, category: category, nutrition: nutritionInfo, tags: [], isPantryStaple: false)
        context.insert(food)
    }

    private func suggestMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
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
    let context: ModelContext
    let foods: [Food]
    let activeProfile: Profile?
    let onProcessing: (String) -> Void
    let onComplete: (String?) -> Void

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
            case .trip:
                let receipt = try await service.extractReceipt(from: text, filterBabyFood: settings.filterBabyFood)
                guard !receipt.items.isEmpty else {
                    onComplete("Couldn't identify any items")
                    return
                }
                createTrip(with: receipt.items)

            case .meal:
                let receipt = try await service.extractReceipt(from: text, filterBabyFood: settings.filterBabyFood)
                guard !receipt.items.isEmpty else {
                    onComplete("Couldn't identify any food items")
                    return
                }
                createMeal(with: receipt.items)

            case .food:
                try await createFood(from: text, service: service)
            }

            try context.save()
            onComplete(nil)
        } catch {
            onComplete("Failed to process: \(error.localizedDescription)")
        }
    }

    private func createTrip(with items: [ExtractedReceiptItem]) {
        let trip = GroceryTrip(date: .now)
        trip.profile = activeProfile
        context.insert(trip)

        for item in items {
            let linkedFood = item.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
            let purchasedItem = PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: linkedFood)
            purchasedItem.trip = trip
            trip.items.append(purchasedItem)
        }
    }

    private func createMeal(with items: [ExtractedReceiptItem]) {
        let meal = Meal(date: .now, mealType: suggestMealType())
        meal.profile = activeProfile
        context.insert(meal)

        for item in items {
            let linkedFood = item.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
            let mealItem = MealItem(name: item.name, quantity: item.quantityGrams, food: linkedFood)
            mealItem.meal = meal
            meal.items.append(mealItem)
        }
    }

    private func createFood(from text: String, service: LLMService) async throws {
        let foodName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = try await service.suggestCategoryAndTags(for: foodName, availableTags: [])
        let nutrition = try await service.estimateNutrition(for: foodName, category: suggestion.category)

        var category = FoodCategory.other
        if let main = FoodMainCategory(rawValue: suggestion.category) {
            let sub = suggestion.subcategory.flatMap { s in main.subcategories.first { $0.rawValue == s } }
            category = FoodCategory(main: main, sub: sub)
        }

        let nutritionInfo = NutritionInfo(from: nutrition, source: .aiEstimate)
        let food = Food(name: foodName, category: category, nutrition: nutritionInfo, tags: [], isPantryStaple: false)
        context.insert(food)
    }

    private func suggestMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }
}
