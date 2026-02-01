import SwiftUI
import SwiftData

enum ItemSortOption: String, CaseIterable, Identifiable {
    case recent = "Recent", name = "Name", calories = "Calories", protein = "Protein"
    case carbs = "Carbs", fat = "Fat", fiber = "Fiber", sugar = "Sugar", price = "Price"

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
        case .price: "dollarsign.circle"
        }
    }

    func value(for item: PurchasedItem) -> Double {
        let n = item.calculatedNutrition
        switch self {
        case .recent, .name: return 0
        case .calories: return n?.calories ?? 0
        case .protein: return n?.protein ?? 0
        case .carbs: return n?.carbohydrates ?? 0
        case .fat: return n?.fat ?? 0
        case .fiber: return n?.fiber ?? 0
        case .sugar: return n?.sugar ?? 0
        case .price: return item.price
        }
    }
}

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var date: Date
    @State private var storeName: String
    @State private var items: [PurchasedItem]
    @State private var deletedItems: [PurchasedItem] = []
    @State private var editingItem: PurchasedItem?
    @State private var showingAddItem = false
    @State private var showingAddItemsAI = false
    @State private var showingSaveError = false
    @State private var sortOption: ItemSortOption = .recent
    @State private var sortAscending = false

    private var existingTrip: GroceryTrip?
    private var isNewTrip: Bool { existingTrip == nil }

    private var sortedItems: [PurchasedItem] {
        let sorted: [PurchasedItem]
        switch sortOption {
        case .recent: sorted = items
        case .name: sorted = items.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
        default: sorted = items.sorted { sortOption.value(for: $0) < sortOption.value(for: $1) }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    private var activeItems: [PurchasedItem] { items.filter { !$0.isSkipped } }
    private var linkedCount: Int { activeItems.filter { $0.food != nil }.count }
    private var totalPrice: Double { activeItems.reduce(0) { $0 + $1.price } }
    private var totalNutrition: (cal: Double, pro: Double, carb: Double, fat: Double, fiber: Double, sugar: Double) {
        activeItems.reduce((0, 0, 0, 0, 0, 0)) { result, item in
            guard let n = item.calculatedNutrition else { return result }
            return (result.0 + n.calories, result.1 + n.protein, result.2 + n.carbohydrates, result.3 + n.fat, result.4 + n.fiber, result.5 + n.sugar)
        }
    }

    init(trip: GroceryTrip?) {
        self.existingTrip = trip
        _date = State(initialValue: trip?.date ?? .now)
        _storeName = State(initialValue: trip?.storeName ?? "")
        _items = State(initialValue: trip?.items ?? [])
    }

    var body: some View {
        Form {
            // Quick Actions + Summary
            Section {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Button { showingAddItemsAI = true } label: {
                            Label("Add Items (AI)", systemImage: "sparkles").frame(maxWidth: .infinity)
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

            // Trip Info
            Section("Trip Info") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Store (optional)", text: $storeName)
            }

            // Items Section
            Section {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Text("No items yet").foregroundStyle(.secondary)
                        Text("Use AI to scan receipts or add items manually").font(.caption).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    ForEach(sortedItems) { item in
                        Button { editingItem = item } label: { ItemRow(item: item) }
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
        .navigationTitle(isNewTrip ? "New Trip" : "Edit Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ItemEditView(item: item, foods: foods) { updated in
                    if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = updated }
                    editingItem = nil
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                ItemEditView(item: nil, foods: foods) { items.append($0); showingAddItem = false }
            }
        }
        .sheet(isPresented: $showingAddItemsAI) {
            AddItemsSheet { extracted in
                for e in extracted {
                    let linkedFood = e.linkedFoodId.flatMap { id in foods.first { $0.id == id } }
                    items.append(PurchasedItem(name: e.name, quantity: e.quantityGrams, price: e.price, food: linkedFood))
                }
                showingAddItemsAI = false
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) { Button("OK") {} } message: {
            Text("Failed to save changes. Please try again.")
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(spacing: 12) {
            // Items & Price Row
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "cart.fill").foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(activeItems.count)").font(.title3).fontWeight(.semibold)
                        Text("\(linkedCount) linked").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill").foregroundStyle(.green)
                    Text(String(format: "%.2f", totalPrice)).font(.title3).fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }

            Divider()

            // Main Macros Row
            HStack(spacing: 0) {
                MacroStat(value: Int(totalNutrition.cal), unit: "kcal", label: "Cal", color: .nutritionCalories)
                MacroStat(value: Int(totalNutrition.pro), unit: "g", label: "Pro", color: .nutritionProtein)
                MacroStat(value: Int(totalNutrition.carb), unit: "g", label: "Carb", color: .nutritionCarbs)
                MacroStat(value: Int(totalNutrition.fat), unit: "g", label: "Fat", color: .nutritionFat)
            }

            // Fiber & Sugar Row
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill").font(.caption).foregroundStyle(.green)
                    Text("\(Int(totalNutrition.fiber))g fiber").font(.caption)
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill").font(.caption).foregroundStyle(.pink)
                    Text("\(Int(totalNutrition.sugar))g sugar").font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)

            // Warning for unlinked items
            if linkedCount < activeItems.count {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("\(activeItems.count - linkedCount) items not linked to food").font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var sortMenu: some View {
        Menu {
            ForEach(ItemSortOption.allCases) { opt in
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

    private func deleteItem(_ item: PurchasedItem) {
        if let i = items.firstIndex(where: { $0.id == item.id }) {
            if item.trip != nil { deletedItems.append(item) }
            _ = withAnimation { items.remove(at: i) }
        }
    }

    private func save() {
        let trip: GroceryTrip
        if let existingTrip {
            trip = existingTrip
            trip.date = date
            trip.storeName = storeName.isEmpty ? nil : storeName
            trip.updatedAt = .now
            deletedItems.forEach { context.delete($0) }
            trip.items.removeAll()
        } else {
            trip = GroceryTrip(date: date, storeName: storeName.isEmpty ? nil : storeName)
            context.insert(trip)
        }
        for item in items { item.trip = trip; trip.items.append(item) }
        do { try context.save(); dismiss() } catch { showingSaveError = true }
    }
}

// MARK: - Supporting Views

private struct MacroStat: View {
    let value: Int, unit: String, label: String, color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("\(value)").font(.subheadline).fontWeight(.semibold)
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
            Text(label).font(.caption2).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ItemRow: View {
    let item: PurchasedItem

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
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(item.quantity))g")
                    Text(String(format: "%.2f", item.price)).foregroundStyle(.secondary)
                }.font(.subheadline)
            }
            if let nutrition = item.calculatedNutrition {
                NutritionSummaryRow(nutrition: nutrition, isCompact: true).opacity(item.isSkipped ? 0.5 : 1)
            }
        }
    }
}
