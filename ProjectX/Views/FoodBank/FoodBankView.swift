import SwiftUI
import SwiftData

struct FoodBankView: View {
    var settings: AppSettings

    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \CustomSubcategory.name) private var allCustomSubs: [CustomSubcategory]

    @State private var searchText = ""
    @AppStorage("foodBankCategory") private var selectedCategoryRaw: String?
    @State private var selectedSubcategory: FoodSubcategory?
    @State private var selectedCustomSub: String?
    @State private var selectedTag: Tag?
    @State private var showingAddFood = false
    @State private var showingAddOptions = false
    @State private var showingNutritionScan = false
    @State private var foodToDelete: Food?
    @State private var isSelecting = false
    @State private var selectedFoodIds: Set<UUID> = []
    @State private var showDeleteSelected = false
    @State private var isAIProcessing = false
    @State private var aiProgressMessage = ""
    @State private var aiError: String?

    private var selectedMainCategory: FoodMainCategory? {
        get { selectedCategoryRaw.flatMap { FoodMainCategory(rawValue: $0) } }
    }

    private func selectCategory(_ category: FoodMainCategory?) {
        selectedCategoryRaw = category?.rawValue
        selectedSubcategory = nil
        selectedCustomSub = nil
    }

    private var customSubcategoriesForSelected: [CustomSubcategory] {
        guard let cat = selectedMainCategory else { return [] }
        return allCustomSubs.filter { $0.mainCategoryRaw == cat.rawValue }
    }

    private var filteredFoods: [Food] {
        foods.filter { food in
            let categoryMatch = selectedMainCategory == nil || food.category.main == selectedMainCategory
            let subMatch: Bool
            if selectedSubcategory != nil {
                subMatch = food.category.sub == selectedSubcategory
            } else if selectedCustomSub != nil {
                subMatch = food.category.customSub == selectedCustomSub
            } else {
                subMatch = true
            }
            let tagMatch = selectedTag == nil || food.tags.contains { $0.id == selectedTag?.id }
            let searchMatch = searchText.isEmpty || food.name.localizedCaseInsensitiveContains(searchText)
            return categoryMatch && subMatch && tagMatch && searchMatch
        }
    }

    private var foodCountByCategory: [FoodMainCategory: Int] {
        Dictionary(grouping: foods, by: { $0.category.main }).mapValues(\.count)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                categorySideBar
                Divider()
                contentArea
            }
            .navigationTitle("Food Bank")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search foods")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if isSelecting {
                        Button("Done") { isSelecting = false; selectedFoodIds.removeAll() }
                    } else {
                        Button { showingAddOptions = true } label: { Label("Add Food", systemImage: "plus") }
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    if !isSelecting && !foods.isEmpty {
                        Button { isSelecting = true } label: { Label("Select", systemImage: "checkmark.circle") }
                    }
                }
            }
            .confirmationDialog("Add Food", isPresented: $showingAddOptions, titleVisibility: .visible) {
                Button("Scan Nutrition Label") { showingNutritionScan = true }
                Button("Manual Entry") { showingAddFood = true }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("How would you like to add a food?")
            }
        }
        .sheet(isPresented: $showingAddFood) {
            NavigationStack { FoodDetailView(food: nil) }
        }
        .fullScreenCover(isPresented: $showingNutritionScan) {
            ScanView(settings: settings, initialMode: .nutritionLabel, onDismiss: { showingNutritionScan = false })
        }
        .deleteConfirmation("Delete Food?", item: $foodToDelete, message: { "Delete \"\($0.name)\"?" }) { food in
            withAnimation { context.delete(food) }
            try? context.save()
        }
        .alert("Delete \(selectedFoodIds.count) Foods?", isPresented: $showDeleteSelected) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { deleteSelectedFoods() }
        } message: { Text("This cannot be undone.") }
        .alert("AI Error", isPresented: .constant(aiError != nil)) {
            Button("OK") { aiError = nil }
        } message: { Text(aiError ?? "") }
        .overlay { if isAIProcessing { AIProcessingOverlay(message: aiProgressMessage) } }
    }

    // MARK: - Side Bar

    private var categorySideBar: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                SideTabItem(icon: "square.grid.2x2", title: "All", count: foods.count,
                           isSelected: selectedMainCategory == nil, color: .themePrimary) {
                    withAnimation { selectCategory(nil) }
                }
                Divider().padding(.vertical, 4)
                ForEach(FoodMainCategory.allCases) { cat in
                    SideTabItem(icon: cat.icon, title: cat.displayName, count: foodCountByCategory[cat] ?? 0,
                               isSelected: selectedMainCategory == cat, color: cat.themeColor) {
                        withAnimation { selectCategory(cat) }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 72)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 0) {
            if let cat = selectedMainCategory, (!cat.subcategories.isEmpty || !customSubcategoriesForSelected.isEmpty) {
                filterBar {
                    FilterChip("All", isSelected: selectedSubcategory == nil && selectedCustomSub == nil, color: cat.themeColor) {
                        selectedSubcategory = nil
                        selectedCustomSub = nil
                    }
                    ForEach(cat.subcategories) { sub in
                        FilterChip(sub.displayName, isSelected: selectedSubcategory == sub, color: cat.themeColor) {
                            selectedSubcategory = sub
                            selectedCustomSub = nil
                        }
                    }
                    ForEach(customSubcategoriesForSelected) { custom in
                        FilterChip(custom.name, isSelected: selectedCustomSub == custom.name, color: cat.themeColor) {
                            selectedCustomSub = custom.name
                            selectedSubcategory = nil
                        }
                    }
                }
            }
            if !allTags.isEmpty {
                filterBar {
                    ForEach(allTags) { tag in
                        TagChip(tag: tag, isSelected: selectedTag?.id == tag.id, showColorDot: true, showDismiss: true) {
                            withAnimation { selectedTag = selectedTag?.id == tag.id ? nil : tag }
                        }
                    }
                }
            }
            foodList
            if isSelecting && !filteredFoods.isEmpty { batchActionBar }
        }
    }

    private var batchActionBar: some View {
        HStack(spacing: 16) {
            Button { toggleSelectAll() } label: {
                Text(selectedFoodIds.count == filteredFoods.count ? "Deselect All" : "Select All").font(.subheadline)
            }
            Spacer()
            Text("\(selectedFoodIds.count) selected").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Menu {
                Button { Task { await batchAISuggestCategory() } } label: {
                    Label("AI Category & Tags", systemImage: "sparkles")
                }.disabled(selectedFoodIds.isEmpty || !settings.isConfigured)
                Button { Task { await batchAIEstimateNutrition() } } label: {
                    Label("AI Estimate Nutrition", systemImage: "sparkles")
                }.disabled(selectedFoodIds.isEmpty || !settings.isConfigured)
                Divider()
                Button(role: .destructive) { showDeleteSelected = true } label: {
                    Label("Delete", systemImage: "trash")
                }.disabled(selectedFoodIds.isEmpty)
            } label: {
                Label("Actions", systemImage: "ellipsis.circle").font(.headline)
            }.disabled(selectedFoodIds.isEmpty)
        }
        .padding(.horizontal).padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    private func filterBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8, content: content).padding(.horizontal).padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Food List

    private var foodList: some View {
        List {
            if foods.isEmpty {
                ContentUnavailableView("No Foods Yet", systemImage: "fork.knife",
                    description: Text("Tap + to add a food manually"))
            } else if filteredFoods.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass",
                    description: Text("Try adjusting your filters"))
            } else {
                ForEach(filteredFoods) { food in
                    foodRow(food)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Selection Actions

    private func toggleSelection(_ id: UUID) {
        if selectedFoodIds.contains(id) { selectedFoodIds.remove(id) }
        else { selectedFoodIds.insert(id) }
    }

    private func toggleSelectAll() {
        if selectedFoodIds.count == filteredFoods.count { selectedFoodIds.removeAll() }
        else { selectedFoodIds = Set(filteredFoods.map(\.id)) }
    }

    @ViewBuilder
    private func foodRow(_ food: Food) -> some View {
        let row = HStack(spacing: 12) {
            if isSelecting {
                Image(systemName: selectedFoodIds.contains(food.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedFoodIds.contains(food.id) ? Color.themePrimary : .secondary)
                    .font(.title3)
                    .onTapGesture { toggleSelection(food.id) }
            }
            FoodRow(food: food)
        }
        if isSelecting {
            row
        } else {
            NavigationLink { FoodDetailView(food: food) } label: { row }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) { DispatchQueue.main.async { foodToDelete = food } } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }

    private func deleteSelectedFoods() {
        let toDelete = foods.filter { selectedFoodIds.contains($0.id) }
        for food in toDelete { context.delete(food) }
        try? context.save()
        selectedFoodIds.removeAll()
        if foods.isEmpty { isSelecting = false }
    }

    private func batchAISuggestCategory() async {
        let tagNames = allTags.map(\.name)
        await runBatchAIOperation(progressLabel: "Suggesting") { service, food in
            let suggestion = try await service.suggestCategoryAndTags(for: food.name, availableTags: tagNames)
            if let main = FoodMainCategory(rawValue: suggestion.category) {
                if let subRaw = suggestion.subcategory,
                   let sub = main.subcategories.first(where: { $0.rawValue == subRaw }) {
                    food.category = FoodCategory(main: main, sub: sub)
                } else {
                    food.category = FoodCategory(main: main, sub: nil)
                }
            }
            food.tags = allTags.filter { suggestion.tags.contains($0.name) }
        }
    }

    private func batchAIEstimateNutrition() async {
        await runBatchAIOperation(progressLabel: "Estimating") { service, food in
            let result = try await service.estimateNutrition(for: food.name, category: food.category.displayName)
            food.nutrition = NutritionInfo(
                calories: result.calories, protein: result.protein, carbohydrates: result.carbohydrates,
                fat: result.fat, saturatedFat: result.saturatedFat, sugar: result.sugar,
                fiber: result.fiber, sodium: result.sodium
            )
        }
    }

    private func runBatchAIOperation(progressLabel: String, operation: (LLMService, Food) async throws -> Void) async {
        guard let service = LLMServiceFactory.create(settings: settings) else {
            aiError = "Please configure your API key in Settings."
            return
        }
        let selectedFoods = foods.filter { selectedFoodIds.contains($0.id) }
        guard !selectedFoods.isEmpty else { return }

        isAIProcessing = true
        var failedCount = 0, successCount = 0

        for (index, food) in selectedFoods.enumerated() {
            aiProgressMessage = "\(progressLabel) \(index + 1)/\(selectedFoods.count)..."
            do {
                try await operation(service, food)
                food.updatedAt = .now
                successCount += 1
            } catch {
                failedCount += 1
            }
        }
        try? context.save()
        isAIProcessing = false
        selectedFoodIds.removeAll()
        isSelecting = false

        if failedCount > 0 {
            aiError = "Completed \(successCount) of \(selectedFoods.count). \(failedCount) failed."
        }
    }
}

// MARK: - Components

private struct SideTabItem: View {
    let icon: String, title: String, count: Int, isSelected: Bool, color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon).font(.title3)
                        .frame(width: 44, height: 36)
                        .background(isSelected ? color : .clear)
                        .foregroundStyle(isSelected ? .white : color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    if count > 0 {
                        Text("\(count)").font(.system(size: 9, weight: .semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(isSelected ? Color.white.opacity(0.3) : color)
                            .clipShape(Capsule()).offset(x: 4, y: -4)
                    }
                }
                Text(title).font(.system(size: 10)).fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1).foregroundStyle(isSelected ? color : .secondary)
            }
            .frame(width: 64, height: 60).contentShape(Rectangle())
        }
        .buttonStyle(.pressFeedback)
    }
}


private struct FoodRow: View {
    let food: Food

    var body: some View {
        HStack {
            Image(systemName: food.category.icon).foregroundStyle(.secondary).frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name).font(.headline)
                HStack(spacing: 8) {
                    if let n = food.nutrition { Text("\(Int(n.calories)) kcal").font(.caption).foregroundStyle(.secondary) }
                    if food.category.hasSubcategory { CapsuleBadge(text: food.category.displayName) }
                }
                if !food.tags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(food.tags.prefix(3)) { CapsuleBadge(text: $0.name, color: $0.color) }
                        if food.tags.count > 3 { Text("+\(food.tags.count - 3)").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
        }
    }
}
