import SwiftUI
import SwiftData

enum ItemSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case calories = "Calories"
    case protein = "Protein"
    case carbs = "Carbs"
    case fat = "Fat"
    case sugar = "Sugar"
    case price = "Price"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .name: return "textformat"
        case .calories: return "flame"
        case .protein: return "p.circle"
        case .carbs: return "c.circle"
        case .fat: return "f.circle"
        case .sugar: return "s.circle"
        case .price: return "dollarsign.circle"
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
    @State private var showingSaveError = false
    @State private var sortOption: ItemSortOption = .name
    @State private var sortAscending = true
    @State private var itemToDelete: PurchasedItem?

    private var existingTrip: GroceryTrip?
    private var isNewTrip: Bool { existingTrip == nil }

    private var sortedItems: [PurchasedItem] {
        let sorted = items.sorted { a, b in
            switch sortOption {
            case .name:
                return a.name.localizedCompare(b.name) == .orderedAscending
            case .calories:
                return (a.calculatedNutrition?.calories ?? 0) < (b.calculatedNutrition?.calories ?? 0)
            case .protein:
                return (a.calculatedNutrition?.protein ?? 0) < (b.calculatedNutrition?.protein ?? 0)
            case .carbs:
                return (a.calculatedNutrition?.carbohydrates ?? 0) < (b.calculatedNutrition?.carbohydrates ?? 0)
            case .fat:
                return (a.calculatedNutrition?.fat ?? 0) < (b.calculatedNutrition?.fat ?? 0)
            case .sugar:
                return (a.calculatedNutrition?.sugar ?? 0) < (b.calculatedNutrition?.sugar ?? 0)
            case .price:
                return a.price < b.price
            }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    init(trip: GroceryTrip?) {
        self.existingTrip = trip
        _date = State(initialValue: trip?.date ?? .now)
        _storeName = State(initialValue: trip?.storeName ?? "")
        _items = State(initialValue: trip?.items ?? [])
    }

    var body: some View {
        Form {
            Section("Trip Info") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Store (optional)", text: $storeName)
            }

            Section {
                if items.isEmpty {
                    VStack(spacing: 8) {
                        Text("No items yet")
                            .foregroundStyle(.secondary)
                        Text("Tap \"Add Item\" below to add items manually")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(sortedItems) { item in
                        Button { editingItem = item } label: { ItemRow(item: item) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { itemToDelete = item } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                Button { showingAddItem = true } label: {
                    Label("Add Item", systemImage: "plus.circle")
                        .foregroundStyle(.blue)
                }
            } header: {
                HStack {
                    Text("Items")
                    Spacer()
                    if !items.isEmpty {
                        Menu {
                            ForEach(ItemSortOption.allCases) { option in
                                Button {
                                    if sortOption == option { sortAscending.toggle() }
                                    else { sortOption = option; sortAscending = option != .name }
                                } label: {
                                    HStack {
                                        Label(option.rawValue, systemImage: option.icon)
                                        if sortOption == option {
                                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(sortOption.rawValue)
                                Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                            }
                            .font(.caption)
                            .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle(isNewTrip ? "New Trip" : "Edit Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ItemEditView(item: item, foods: foods) { updatedItem in
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        items[index] = updatedItem
                    }
                    editingItem = nil
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                ItemEditView(item: nil, foods: foods) { newItem in
                    items.append(newItem)
                    showingAddItem = false
                }
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: {
            Text("Failed to save changes. Please try again.")
        }
        .deleteConfirmation("Delete Item?", item: $itemToDelete, message: { item in
            "Remove \"\(item.name)\" from this trip?"
        }) { item in
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                if item.trip != nil { deletedItems.append(item) }
                _ = withAnimation { items.remove(at: index) }
            }
        }
    }

    private func save() {
        let trip: GroceryTrip
        if let existingTrip {
            trip = existingTrip
            trip.date = date
            trip.storeName = storeName.isEmpty ? nil : storeName
            trip.updatedAt = .now

            // Delete removed items from persistence
            for item in deletedItems {
                context.delete(item)
            }

            trip.items.removeAll()
        } else {
            trip = GroceryTrip(date: date, storeName: storeName.isEmpty ? nil : storeName)
            context.insert(trip)
        }

        for item in items {
            item.trip = trip
            trip.items.append(item)
        }

        do {
            try context.save()
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}

// MARK: - Item Row

private struct ItemRow: View {
    let item: PurchasedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(item.isSkipped ? .secondary : .primary)
                        .strikethrough(item.isSkipped)
                    if let food = item.food {
                        Text(food.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(item.quantity))g")
                    Text(String(format: "%.2f", item.price))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }

            // Nutrition row if food is linked
            if let nutrition = item.calculatedNutrition {
                NutritionSummaryRow(nutrition: nutrition, isCompact: true)
                    .opacity(item.isSkipped ? 0.5 : 1)
            }
        }
    }
}

// MARK: - Nutrition Summary Row

struct NutritionSummaryRow: View {
    let nutrition: NutritionInfo
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            nutrientLabel("Cal", value: nutrition.calories, unit: "", color: .nutritionCalories)
            nutrientLabel("P", value: nutrition.protein, unit: "g", color: .nutritionProtein)
            nutrientLabel("C", value: nutrition.carbohydrates, unit: "g", color: .nutritionCarbs)
            nutrientLabel("F", value: nutrition.fat, unit: "g", color: .nutritionFat)
            nutrientLabel("S", value: nutrition.sugar, unit: "g", color: .nutritionSugar)
        }
        .font(isCompact ? .caption2 : .caption)
    }

    private func nutrientLabel(_ label: String, value: Double, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .fontWeight(.medium)
                .foregroundStyle(color)
            Text("\(Int(value))\(unit)")
                .foregroundStyle(.secondary)
        }
    }
}
