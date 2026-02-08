import SwiftUI
import SwiftData

struct ContentView: View {
    @Bindable var settings: AppSettings
    @Environment(\.importManager) private var importManager
    @Environment(\.scanFlowManager) private var scanFlowManager
    @Environment(\.modelContext) private var context
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var showingScan = false
    @State private var showingNutritionScan = false
    @State private var showingAddOptions = false
    @State private var showingDirectCamera = false
    @State private var directCameraMode: QuickAddMode?
    @State private var pendingImportImage: UIImage?
    @State private var showReviewFromImport = false
    @State private var showNutritionFromImport = false
    @State private var isProcessingImport = false
    @State private var importError: String?

    private var quickAddMode: QuickAddMode? {
        QuickAddMode(rawValue: selectedTab)
    }

    private var showFAB: Bool {
        selectedTab <= 2  // Show on Trips, Meals, Foods tabs only
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                HomeView(settings: settings).tabItem { Label("Trips", systemImage: "cart.fill") }.tag(0)
                MealsView(settings: settings).tabItem { Label("Meals", systemImage: "fork.knife.circle") }.tag(1)
                FoodBankView(settings: settings).tabItem { Label("Foods", systemImage: "fork.knife") }.tag(2)
                AnalysisView(settings: settings).tabItem { Label("Analysis", systemImage: "chart.bar.fill") }.tag(3)
                SettingsView(settings: settings).tabItem { Label("Settings", systemImage: "gearshape.fill") }.tag(4)
            }
            if showFAB {
                floatingAddButton
            }
        }
        .fullScreenCover(isPresented: $showingScan) {
            ScanView(settings: settings, onDismiss: { showingScan = false })
        }
        .fullScreenCover(isPresented: $showingNutritionScan) {
            ScanView(settings: settings, initialMode: .nutritionLabel, onDismiss: { showingNutritionScan = false })
        }
        .fullScreenCover(isPresented: $showingDirectCamera) {
            CameraView(sourceType: .camera, onImageCaptured: handleDirectCameraCapture, onCancel: { showingDirectCamera = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingAddOptions) {
            if let mode = quickAddMode {
                QuickAddSheet(settings: settings, mode: mode, onScanPhoto: {
                    showingAddOptions = false
                    directCameraMode = mode
                    showingDirectCamera = true
                })
                .presentationDetents([.height(240)])
            }
        }
        .sheet(isPresented: .init(get: { importManager.showingImportTypeSelection }, set: { importManager.showingImportTypeSelection = $0 })) {
            importTypeSheet
        }
        .fullScreenCover(isPresented: $showReviewFromImport) {
            if let image = pendingImportImage { NavigationStack { ReceiptReviewView(image: image, settings: settings) } }
        }
        .fullScreenCover(isPresented: $showNutritionFromImport) {
            if let image = pendingImportImage { NavigationStack { NutritionLabelResultView(image: image, settings: settings) } }
        }
        .overlay { if isProcessingImport { processingOverlay } }
        .alert("Error", isPresented: .constant(importError != nil)) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
        .onChange(of: scanFlowManager.requestScanTab) { _, request in
            if request { showingScan = true; scanFlowManager.requestScanTab = false }
        }
        .onAppear { ensureProfileAndMigrateData() }
    }

    private func ensureProfileAndMigrateData() {
        let profileDescriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
        let profiles = (try? context.fetch(profileDescriptor)) ?? []

        var defaultProfile: Profile
        if profiles.isEmpty {
            defaultProfile = Profile(name: "Default", isDefault: true)
            context.insert(defaultProfile)
            settings.activeProfileId = defaultProfile.id
        } else if let existing = profiles.first(where: { $0.isDefault }) ?? profiles.first {
            defaultProfile = existing
            if settings.activeProfileId == nil {
                settings.activeProfileId = defaultProfile.id
            }
        } else {
            return
        }

        // Migrate orphaned trips
        let tripDescriptor = FetchDescriptor<GroceryTrip>()
        if let orphanedTrips = try? context.fetch(tripDescriptor) {
            for trip in orphanedTrips where trip.profile == nil {
                trip.profile = defaultProfile
            }
        }

        // Migrate orphaned meals
        let mealDescriptor = FetchDescriptor<Meal>()
        if let orphanedMeals = try? context.fetch(mealDescriptor) {
            for meal in orphanedMeals where meal.profile == nil {
                meal.profile = defaultProfile
            }
        }

        try? context.save()
    }

    private var floatingAddButton: some View {
        Button { showingAddOptions = true } label: {
            Circle().fill(Color.themePrimary).frame(width: 56, height: 56)
                .shadow(color: Color.themePrimary.opacity(0.4), radius: 8, y: 4)
                .overlay { Image(systemName: "plus").font(.system(size: 24, weight: .semibold)).foregroundStyle(.white) }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 90)
    }

    private var importTypeSheet: some View {
        ScanTypeSelectionSheet(
            onSelect: { type in importManager.showingImportTypeSelection = false; Task { await processImportedContent(type: type) } },
            onCancel: { importManager.showingImportTypeSelection = false; importManager.pendingImport = nil }
        ).presentationDetents([.medium])
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Processing...").font(.headline).foregroundStyle(.white)
            }.padding(32).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func handleDirectCameraCapture(_ image: UIImage) {
        showingDirectCamera = false
        guard let mode = directCameraMode else { return }

        Task {
            isProcessingImport = true
            defer { isProcessingImport = false }

            guard let service = LLMServiceFactory.create(settings: settings) else {
                importError = "Please configure your API key in Settings"
                return
            }

            do {
                switch mode {
                case .trip:
                    let receipt = try await service.extractReceipt(from: image, filterBabyFood: settings.filterBabyFood)
                    guard !receipt.items.isEmpty else {
                        importError = "Couldn't identify any items"
                        return
                    }
                    createTrip(with: receipt.items)

                case .meal:
                    let receipt = try await service.extractReceipt(from: image, filterBabyFood: settings.filterBabyFood)
                    guard !receipt.items.isEmpty else {
                        importError = "Couldn't identify any food items"
                        return
                    }
                    createMeal(with: receipt.items)

                case .food:
                    let nutrition = try await service.extractNutritionLabel(from: image)
                    createFood(with: nutrition)
                }

                try context.save()
            } catch {
                importError = "Failed to process: \(error.localizedDescription)"
            }
        }
    }

    private func createTrip(with items: [ExtractedReceiptItem]) {
        let descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
        let profiles = (try? context.fetch(descriptor)) ?? []
        let activeProfile = profiles.first { $0.id == settings.activeProfileId }

        let foodDescriptor = FetchDescriptor<Food>(sortBy: [SortDescriptor(\.name)])
        let foods = (try? context.fetch(foodDescriptor)) ?? []

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
        let descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.createdAt)])
        let profiles = (try? context.fetch(descriptor)) ?? []
        let activeProfile = profiles.first { $0.id == settings.activeProfileId }

        let foodDescriptor = FetchDescriptor<Food>(sortBy: [SortDescriptor(\.name)])
        let foods = (try? context.fetch(foodDescriptor)) ?? []

        let hour = Calendar.current.component(.hour, from: Date())
        let mealType: MealType = switch hour {
            case 5..<11: .breakfast
            case 11..<15: .lunch
            case 15..<18: .snack
            default: .dinner
        }

        let meal = Meal(date: .now, mealType: mealType)
        meal.profile = activeProfile
        context.insert(meal)

        for item in items {
            let linkedFood = item.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
            let mealItem = MealItem(name: item.name, quantity: item.quantityGrams, food: linkedFood)
            mealItem.meal = meal
            meal.items.append(mealItem)
        }
    }

    private func createFood(with nutrition: ExtractedNutrition) {
        let nutritionInfo = NutritionInfo(from: nutrition, source: .labelScan)
        let food = Food(name: "Scanned Food", category: .other, nutrition: nutritionInfo, tags: [], isPantryStaple: false)
        context.insert(food)
    }

    private func processImportedContent(type: ScanView.ScanType) async {
        guard let source = importManager.pendingImport else { return }
        isProcessingImport = true
        defer { isProcessingImport = false; importManager.pendingImport = nil }

        // Convert source to UIImage
        let image: UIImage?
        switch source {
        case .image(let img):
            image = img
        case .pdf(let data):
            image = extractImageFromPDF(data)
        case .text:
            importError = "Text import not supported in this flow"
            return
        }

        guard let img = image else {
            importError = "Failed to process image"
            return
        }

        pendingImportImage = img
        selectedTab = 2  // Navigate to Foods tab
        if type == .receipt { showReviewFromImport = true } else { showNutritionFromImport = true }
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
}
