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
    @State private var pendingImportPDF: Data?
    @State private var showReviewFromImport = false
    @State private var showNutritionFromImport = false
    @State private var isProcessingImport = false
    @State private var importError: String?

    // Edit view states for QuickAdd flow
    @State private var pendingTripItems: [PurchasedItem] = []
    @State private var pendingTripStoreName: String?
    @State private var pendingTripDate: Date?
    @State private var pendingMealItems: [MealItem] = []
    @State private var pendingMealDate: Date?
    @State private var pendingFoodData: (name: String, category: FoodCategory, nutrition: NutritionInfo?)?
    @State private var showingTripEdit = false
    @State private var showingMealEdit = false
    @State private var showingFoodEdit = false

    @Query(sort: \Profile.createdAt) private var profiles: [Profile]

    private var activeProfile: Profile? {
        profiles.first { $0.id == settings.activeProfileId }
    }

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
        .sheet(isPresented: $showingAddOptions, onDismiss: presentPendingEditView) {
            if let mode = quickAddMode {
                QuickAddSheet(
                    settings: settings,
                    mode: mode,
                    onScanPhoto: {
                        showingAddOptions = false
                        directCameraMode = mode
                        showingDirectCamera = true
                    },
                    onTripItems: { items, storeName, date in
                        pendingTripItems = items
                        pendingTripStoreName = storeName
                        pendingTripDate = date
                    },
                    onMealItems: { items, date in
                        pendingMealItems = items
                        pendingMealDate = date
                    },
                    onFoodData: { name, category, nutrition in
                        pendingFoodData = (name, category, nutrition)
                    }
                )
                .presentationDetents([.height(240)])
            }
        }
        .sheet(isPresented: .init(get: { importManager.showingImportTypeSelection }, set: { importManager.showingImportTypeSelection = $0 })) {
            importTypeSheet
        }
        .fullScreenCover(isPresented: $showReviewFromImport) {
            if let pdf = pendingImportPDF {
                NavigationStack { ReceiptReviewView(pdfData: pdf, settings: settings) }
            } else if let image = pendingImportImage {
                NavigationStack { ReceiptReviewView(image: image, settings: settings) }
            }
        }
        .fullScreenCover(isPresented: $showNutritionFromImport) {
            if let pdf = pendingImportPDF {
                NavigationStack { NutritionLabelResultView(pdfData: pdf, settings: settings) }
            } else if let image = pendingImportImage {
                NavigationStack { NutritionLabelResultView(image: image, settings: settings) }
            }
        }
        .fullScreenCover(isPresented: $showingTripEdit, onDismiss: clearPendingTripData) {
            NavigationStack {
                TripDetailView(items: pendingTripItems, storeName: pendingTripStoreName, date: pendingTripDate, profile: activeProfile, settings: settings)
            }
        }
        .fullScreenCover(isPresented: $showingMealEdit, onDismiss: clearPendingMealData) {
            NavigationStack {
                MealDetailView(items: pendingMealItems, date: pendingMealDate, profile: activeProfile, settings: settings)
            }
        }
        .fullScreenCover(isPresented: $showingFoodEdit, onDismiss: { pendingFoodData = nil }) {
            if let data = pendingFoodData {
                NavigationStack {
                    FoodDetailView(name: data.name, category: data.category, nutrition: data.nutrition, settings: settings)
                }
            }
        }
        .overlay { if isProcessingImport { processingOverlay } }
        .alert("Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
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

    private func presentPendingEditView() {
        if !pendingTripItems.isEmpty {
            showingTripEdit = true
        } else if !pendingMealItems.isEmpty {
            showingMealEdit = true
        } else if pendingFoodData != nil {
            showingFoodEdit = true
        }
    }

    private func clearPendingTripData() {
        pendingTripItems = []
        pendingTripStoreName = nil
        pendingTripDate = nil
    }

    private func clearPendingMealData() {
        pendingMealItems = []
        pendingMealDate = nil
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

            let foodDescriptor = FetchDescriptor<Food>(sortBy: [SortDescriptor(\.name)])
            let foods = (try? context.fetch(foodDescriptor)) ?? []

            do {
                switch mode {
                case .trip, .meal:
                    let receipt = try await service.extractReceipt(from: image, filterBabyFood: settings.filterBabyFood)
                    guard !receipt.items.isEmpty else {
                        importError = "Couldn't identify any items"
                        return
                    }
                    if mode == .trip {
                        pendingTripItems = ItemMapper.mapToTripItems(receipt.items, foods: foods)
                        pendingTripStoreName = receipt.storeName
                        pendingTripDate = receipt.parsedDate
                        showingTripEdit = true
                    } else {
                        pendingMealItems = ItemMapper.mapToMealItems(receipt.items, foods: foods)
                        pendingMealDate = receipt.parsedDate
                        showingMealEdit = true
                    }

                case .food:
                    let nutrition = try await service.extractNutritionLabel(from: image)
                    pendingFoodData = (ItemMapper.extractedFoodName(from: nutrition), .other, NutritionInfo(from: nutrition, source: .labelScan))
                    showingFoodEdit = true
                }
            } catch {
                importError = "Failed to process: \(error.localizedDescription)"
            }
        }
    }

    private func processImportedContent(type: ScanView.ScanType) async {
        guard let source = importManager.pendingImport else { return }
        isProcessingImport = true
        defer { isProcessingImport = false; importManager.pendingImport = nil }

        // Clear previous state
        pendingImportImage = nil
        pendingImportPDF = nil

        switch source {
        case .image(let img):
            pendingImportImage = img
        case .pdf(let data):
            pendingImportPDF = data  // Keep PDF data for direct LLM processing
        case .text:
            importError = "Text import not supported in this flow"
            return
        }

        selectedTab = 2  // Navigate to Foods tab
        if type == .receipt { showReviewFromImport = true } else { showNutritionFromImport = true }
    }
}
