import SwiftUI
import SwiftData

enum MealItemSortOption: String, CaseIterable, Identifiable {
    case recent = "Recent", name = "Name", calories = "Calories", protein = "Protein"
    case carbs = "Carbs", fat = "Fat", fiber = "Fiber", sugar = "Sugar"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .recent: "clock"
        case .name: "textformat"
        case .calories: "flame"
        case .protein: "p.circle"
        case .carbs: "c.circle"
        case .fat: "f.circle"
        case .fiber: "leaf"
        case .sugar: "s.circle"
        }
    }

    func value(for item: MealItem) -> Double {
        let n = item.calculatedNutrition
        switch self {
        case .recent, .name: return 0
        case .calories: return n?.calories ?? 0
        case .protein: return n?.protein ?? 0
        case .carbs: return n?.carbohydrates ?? 0
        case .fat: return n?.fat ?? 0
        case .fiber: return n?.fiber ?? 0
        case .sugar: return n?.sugar ?? 0
        }
    }
}

struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    let settings: AppSettings
    @State private var date: Date
    @State private var mealType: MealType
    @State private var notes: String
    @State private var items: [MealItem]
    @State private var deletedItems: [MealItem] = []
    @State private var editingItem: MealItem?
    @State private var showingAddItem = false
    @State private var showingAddItemsAI = false
    @State private var showingSaveError = false
    @State private var showingDiscardAlert = false
    @State private var sortOption: MealItemSortOption = .recent
    @State private var sortAscending = false

    private var existingMeal: Meal?
    private var profile: Profile?
    private var isNewMeal: Bool { existingMeal == nil }
    private let originalItemCount: Int

    private var sortedItems: [MealItem] {
        let sorted: [MealItem]
        switch sortOption {
        case .recent: sorted = items
        case .name: sorted = items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        default: sorted = items.sorted { sortOption.value(for: $0) < sortOption.value(for: $1) }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    private var hasChanges: Bool {
        items.count != originalItemCount || !deletedItems.isEmpty
    }

    private var activeItems: [MealItem] { items.filter { !$0.isSkipped } }
    private var linkedCount: Int { activeItems.filter { $0.food != nil }.count }
    private var totalNutrition: (cal: Double, pro: Double, carb: Double, fat: Double, fiber: Double, sugar: Double) {
        activeItems.reduce((0, 0, 0, 0, 0, 0)) { result, item in
            guard let n = item.calculatedNutrition else { return result }
            return (result.0 + n.calories, result.1 + n.protein, result.2 + n.carbohydrates, result.3 + n.fat, result.4 + n.fiber, result.5 + n.sugar)
        }
    }

    init(meal: Meal?, profile: Profile? = nil, settings: AppSettings) {
        self.existingMeal = meal
        self.profile = profile
        self.settings = settings
        self.originalItemCount = meal?.items.count ?? 0
        _date = State(initialValue: meal?.date ?? .now)
        _mealType = State(initialValue: meal?.mealType ?? .lunch)
        _notes = State(initialValue: meal?.notes ?? "")
        _items = State(initialValue: meal?.items ?? [])
    }

    /// Initialize with pre-populated items for a new meal (from import/scan)
    init(items: [MealItem], date: Date? = nil, profile: Profile?, settings: AppSettings) {
        self.existingMeal = nil
        self.profile = profile
        self.settings = settings
        self.originalItemCount = items.count
        let mealDate = date ?? .now
        _date = State(initialValue: mealDate)
        _mealType = State(initialValue: Self.suggestMealType(for: mealDate))
        _notes = State(initialValue: "")
        _items = State(initialValue: items)
    }

    private static func suggestMealType(for date: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 15..<18: return .snack
        default: return .dinner
        }
    }

    var body: some View {
        Form {
            // Quick Actions + Summary
            Section {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button { showingAddItemsAI = true } label: {
                            Label("Add Foods (AI)", systemImage: "sparkles").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent).tint(Color.themePrimary)
                        Button { showingAddItem = true } label: {
                            Label("Manual", systemImage: "plus").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered).tint(Color.themePrimary)
                    }
                    if !items.isEmpty { summaryCard }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Meal Info
            Section("Meal Info") {
                DatePicker("Date & Time", selection: $date)
                Picker("Meal Type", selection: $mealType) {
                    ForEach(MealType.allCases) { type in
                        Label(type.rawValue, systemImage: type.icon).tag(type)
                    }
                }
                TextField("Notes (optional)", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            // Items Section
            Section {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Text("No items yet").foregroundStyle(.secondary)
                        Text("Use AI to add foods or add items manually").font(.caption).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    ForEach(sortedItems) { item in
                        Button { editingItem = item } label: { MealItemRow(item: item) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) { deleteItem(item) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                HStack {
                    Text("Items (\(items.count))")
                    Spacer()
                    if !items.isEmpty { sortMenu }
                }
            }
        }
        .navigationTitle(isNewMeal ? "New Meal" : "Edit Meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    if hasChanges {
                        showingDiscardAlert = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ItemEditView(mealItem: item, foods: foods, settings: settings) { updated in
                    if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = updated }
                    editingItem = nil
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                ItemEditView(mealItem: nil, foods: foods, settings: settings) { items.append($0); showingAddItem = false }
            }
        }
        .sheet(isPresented: $showingAddItemsAI) {
            AddItemsSheet(settings: settings) { extracted in
                for e in extracted {
                    let linkedFood = e.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
                    items.append(MealItem(name: e.name, quantity: e.quantityGrams, food: linkedFood))
                }
                showingAddItemsAI = false
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) { Button("OK") {} } message: {
            Text("Failed to save changes. Please try again.")
        }
        .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You have unsaved changes that will be lost.")
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        NutritionSummaryCard(
            activeItemCount: activeItems.count,
            linkedCount: linkedCount,
            nutrition: totalNutrition,
            icon: "fork.knife"
        )
    }

    private var sortMenu: some View {
        Menu {
            ForEach(MealItemSortOption.allCases) { opt in
                Button {
                    if sortOption == opt { sortAscending.toggle() }
                    else { sortOption = opt; sortAscending = (opt == .name) }
                } label: {
                    HStack {
                        Label(opt.rawValue, systemImage: opt.icon)
                        if sortOption == opt { Image(systemName: sortAscending ? "chevron.up" : "chevron.down") }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sortOption.rawValue)
                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
            }.font(.caption).foregroundStyle(Color.themePrimary)
        }
    }

    // MARK: - Actions

    private func deleteItem(_ item: MealItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            if item.meal != nil { deletedItems.append(item) }
            _ = withAnimation { items.remove(at: i) }
        }
    }

    private func save() {
        let meal: Meal
        if let existingMeal {
            meal = existingMeal
            meal.date = date
            meal.mealType = mealType
            meal.notes = notes.isEmpty ? nil : notes
            meal.updatedAt = .now
            deletedItems.forEach { context.delete($0) }
            meal.items.removeAll()
        } else {
            meal = Meal(date: date, mealType: mealType, notes: notes.isEmpty ? nil : notes)
            meal.profile = profile
            context.insert(meal)
        }
        for item in items { item.meal = meal; meal.items.append(item) }
        do { try context.save(); dismiss() } catch { showingSaveError = true }
    }
}

// MARK: - Meal Item Row

struct MealItemRow: View {
    let item: MealItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.name).font(.headline)
                            .foregroundStyle(item.isSkipped ? .secondary : .primary)
                            .strikethrough(item.isSkipped)
                        if item.food == nil && !item.isSkipped {
                            Image(systemName: "link.badge.plus").font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if let food = item.food {
                        Text(food.name).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("\(Int(item.quantity))g")
                    .font(.subheadline)
            }
            if let nutrition = item.calculatedNutrition {
                NutritionSummaryRow(nutrition: nutrition, isCompact: true).opacity(item.isSkipped ? 0.5 : 1)
            }
        }
    }
}
