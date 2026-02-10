import SwiftUI
import SwiftData

struct ContentView: View {
    enum ActiveFullScreenCover: Identifiable {
        case scan, addItems, reviewImport, nutritionImport, tripEdit, mealEdit, foodEdit
        var id: Self { self }
    }

    @Bindable var settings: AppSettings
    @Environment(\.importManager) private var importManager
    @Environment(\.scanFlowManager) private var scanFlowManager
    @Environment(\.modelContext) private var context
    @AppStorage("selectedTab") private var selectedTab = 0
    @State private var activeFullScreenCover: ActiveFullScreenCover?
    @State private var lastFullScreenCover: ActiveFullScreenCover?
    @State private var showingAddOptions = false
    @State private var directCameraMode: QuickAddMode?
    @State private var pendingImportImage: UIImage?
    @State private var pendingImportPDF: Data?
    @State private var isProcessingImport = false
    @State private var importError: String?

    // Edit view states for QuickAdd flow
    @State private var pendingTripItems: [PurchasedItem] = []
    @State private var pendingTripStoreName: String?
    @State private var pendingTripDate: Date?
    @State private var pendingMealItems: [MealItem] = []
    @State private var pendingMealDate: Date?
    @State private var pendingFoodData: (name: String, category: FoodCategory, nutrition: NutritionInfo?)?
    @State private var pendingFoodPreparation: String?

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
        .fullScreenCover(item: $activeFullScreenCover, onDismiss: handleFullScreenCoverDismiss) { cover in
            switch cover {
            case .scan:
                ScanView(settings: settings, onDismiss: { activeFullScreenCover = nil })
            case .addItems:
                if let mode = directCameraMode {
                    NavigationStack {
                        AddItemsSheet(settings: settings, quickAddMode: mode) { extracted in
                            handleExtractedItems(extracted, mode: mode)
                        }
                    }
                } else {
                    // directCameraMode should always be set before presenting .addItems
                    Color.clear.onAppear { activeFullScreenCover = nil }
                }
            case .reviewImport:
                if let pdf = pendingImportPDF {
                    NavigationStack { ReceiptReviewView(pdfData: pdf, settings: settings) }
                } else if let image = pendingImportImage {
                    NavigationStack { ReceiptReviewView(image: image, settings: settings) }
                }
            case .nutritionImport:
                if let pdf = pendingImportPDF {
                    NavigationStack { NutritionLabelResultView(pdfData: pdf, settings: settings) }
                } else if let image = pendingImportImage {
                    NavigationStack { NutritionLabelResultView(image: image, settings: settings) }
                }
            case .tripEdit:
                NavigationStack {
                    TripDetailView(items: pendingTripItems, storeName: pendingTripStoreName, date: pendingTripDate, profile: activeProfile, settings: settings)
                }
            case .mealEdit:
                NavigationStack {
                    MealDetailView(items: pendingMealItems, date: pendingMealDate, profile: activeProfile, settings: settings)
                }
            case .foodEdit:
                if let data = pendingFoodData {
                    NavigationStack {
                        FoodDetailView(name: data.name, category: data.category, nutrition: data.nutrition, settings: settings)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddOptions, onDismiss: presentPendingEditView) {
            if let mode = quickAddMode {
                QuickAddSheet(
                    settings: settings,
                    mode: mode,
                    onScanPhoto: {
                        showingAddOptions = false
                        directCameraMode = mode
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            activeFullScreenCover = .addItems
                        }
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
        .overlay { if isProcessingImport { processingOverlay } }
        .alert("Error", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
        .onChange(of: scanFlowManager.requestScanTab) { _, request in
            if request { activeFullScreenCover = .scan; scanFlowManager.requestScanTab = false }
        }
        .onAppear { ensureProfileAndMigrateData() }
        .onChange(of: activeFullScreenCover) { _, newValue in
            if let newValue { lastFullScreenCover = newValue }
        }
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

    private func handleFullScreenCoverDismiss() {
        switch lastFullScreenCover {
        case .addItems:
            if let foodName = pendingFoodPreparation {
                // Food mode needs async AI processing before presenting edit view
                pendingFoodPreparation = nil
                Task {
                    isProcessingImport = true
                    defer { isProcessingImport = false }
                    guard let service = LLMServiceFactory.create(settings: settings) else {
                        importError = "Please configure your API key in Settings"
                        return
                    }
                    do {
                        let (name, category, nutrition) = try await ItemMapper.prepareFoodData(from: foodName, service: service)
                        pendingFoodData = (name, category, nutrition)
                        activeFullScreenCover = .foodEdit
                    } catch {
                        importError = "Failed to process food: \(error.localizedDescription)"
                    }
                }
            } else {
                presentPendingEditView()
            }
        case .tripEdit: clearPendingTripData()
        case .mealEdit: clearPendingMealData()
        case .foodEdit: pendingFoodData = nil
        default: break
        }
    }

    private func presentPendingEditView() {
        if !pendingTripItems.isEmpty {
            activeFullScreenCover = .tripEdit
        } else if !pendingMealItems.isEmpty {
            activeFullScreenCover = .mealEdit
        } else if pendingFoodData != nil {
            activeFullScreenCover = .foodEdit
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

    /// Maps extracted items to model objects, resolving AI-assigned `linkedFoodId` to Food objects.
    /// Unlike `ItemMapper` (which does local string matching), this preserves the AI-based linking
    /// already performed by `AddItemsSheet.autoLinkFoods`.
    private func handleExtractedItems(_ extracted: [ExtractedReceiptItem], mode: QuickAddMode) {
        let foodDescriptor = FetchDescriptor<Food>(sortBy: [SortDescriptor(\.name)])
        let foods = (try? context.fetch(foodDescriptor)) ?? []

        switch mode {
        case .trip:
            pendingTripItems = extracted.map { item in
                let linkedFood = item.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
                return PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: linkedFood)
            }

        case .meal:
            pendingMealItems = extracted.map { item in
                let linkedFood = item.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
                return MealItem(name: item.name, quantity: item.quantityGrams, food: linkedFood)
            }

        case .food:
            if let first = extracted.first {
                pendingFoodPreparation = first.name
            }
        }
        // The AddItemsSheet will dismiss (setting activeFullScreenCover = nil),
        // then handleFullScreenCoverDismiss presents the appropriate edit view.
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
        activeFullScreenCover = type == .receipt ? .reviewImport : .nutritionImport
    }
}
