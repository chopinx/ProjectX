import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: String
    @State private var price: String
    @State private var selectedFood: Food?
    @State private var isSkipped: Bool
    @State private var showFoodMatching = false

    private let existingItem: PurchasedItem?
    private let foods: [Food]
    private let onSave: (PurchasedItem) -> Void

    init(item: PurchasedItem?, foods: [Food], onSave: @escaping (PurchasedItem) -> Void) {
        self.existingItem = item
        self.foods = foods
        self.onSave = onSave
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item != nil ? String(format: "%.0f", item!.quantity) : "")
        _price = State(initialValue: item != nil ? String(format: "%.2f", item!.price) : "")
        _selectedFood = State(initialValue: item?.food)
        _isSkipped = State(initialValue: item?.isSkipped ?? false)
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                HStack {
                    TextField("Quantity", text: $quantity).keyboardType(.decimalPad)
                        .onChange(of: quantity) { _, v in quantity = v.filter { $0.isNumber || $0 == "." } }
                    Text("g").foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Price", text: $price).keyboardType(.decimalPad)
                        .onChange(of: price) { _, v in price = v.filter { $0.isNumber || $0 == "." } }
                }
            } header: {
                Text("Item Details")
            } footer: {
                if !quantity.isEmpty && Double(quantity) == nil {
                    Text("Please enter a valid number").foregroundStyle(Color.themeError)
                }
            }

            Section("Link to Food") {
                Button { showFoodMatching = true } label: {
                    HStack {
                        Text(selectedFood?.name ?? "Select Food")
                            .foregroundStyle(selectedFood == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                }
                if let food = selectedFood, let nutrition = food.nutrition, let qty = Double(quantity) {
                    let scaled = nutrition.scaled(byGrams: qty)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nutrition for \(Int(qty))g:").font(.caption).foregroundStyle(.secondary)
                        Text("\(Int(scaled.calories)) kcal, \(Int(scaled.protein))g protein").font(.caption)
                    }
                }
            }

            Section {
                Toggle("Skip this item", isOn: $isSkipped)
            } footer: {
                Text("Skipped items won't count toward nutrition totals")
            }
        }
        .navigationTitle(existingItem == nil ? "Add Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let qty = Double(quantity), let prc = Double(price) else { return }
                    let item = existingItem ?? PurchasedItem(name: name, quantity: qty, price: prc)
                    item.name = name; item.quantity = qty; item.price = prc
                    item.food = selectedFood; item.isSkipped = isSkipped
                    onSave(item)
                }
                .disabled(name.isEmpty || Double(quantity) == nil || Double(price) == nil)
            }
        }
        .sheet(isPresented: $showFoodMatching) {
            NavigationStack {
                FoodMatchingView(itemName: name, foods: foods, currentMatch: selectedFood) { food in
                    selectedFood = food
                    showFoodMatching = false
                }
            }
        }
    }
}

// MARK: - Food Matching with AI Suggestions

private struct FoodMatchingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let itemName: String
    let foods: [Food]
    let currentMatch: Food?
    let onSelect: (Food?) -> Void

    @State private var selectedFood: Food?
    @State private var suggestedFood: Food?
    @State private var isLoading = true
    @State private var showingNewFood = false
    @State private var searchText = ""
    @State private var settings = AppSettings()

    private var filtered: [Food] {
        searchText.isEmpty ? foods : foods.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if isLoading && !itemName.isEmpty {
                Section("AI Suggestion") {
                    HStack { ProgressView(); Text("Finding best match...").foregroundStyle(.secondary) }
                }
            } else if let suggested = suggestedFood {
                Section("AI Suggestion") {
                    FoodRow(food: suggested, isSelected: selectedFood?.id == suggested.id, badge: "Suggested") {
                        selectedFood = suggested
                    }
                }
            }

            Section {
                Button { showingNewFood = true } label: {
                    Label("Create New Food", systemImage: "plus.circle.fill")
                }
            }

            Section("All Foods") {
                if filtered.isEmpty {
                    Text("No foods found").foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { food in
                        FoodRow(food: food, isSelected: selectedFood?.id == food.id) { selectedFood = food }
                    }
                }
            }

            Section {
                Button(role: .destructive) { selectedFood = nil } label: {
                    Label("Remove Link", systemImage: "link.badge.minus")
                }.disabled(selectedFood == nil && currentMatch == nil)
            }
        }
        .searchable(text: $searchText, prompt: "Search foods")
        .navigationTitle("Link to Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Done") { onSelect(selectedFood) } }
        }
        .task { selectedFood = currentMatch; await findSuggestion() }
        .sheet(isPresented: $showingNewFood) {
            NavigationStack {
                FoodDetailView(suggestedName: itemName, suggestedCategory: "other") { newFood in
                    selectedFood = newFood
                    showingNewFood = false
                }
            }
        }
    }

    private func findSuggestion() async {
        guard !foods.isEmpty, !itemName.isEmpty,
              let service = LLMServiceFactory.create(settings: settings) else { isLoading = false; return }
        do {
            let match = try await service.matchFood(itemName: itemName, existingFoods: foods.map(\.name))
            if !match.isNewFood, let name = match.foodName {
                suggestedFood = foods.first { $0.name.lowercased() == name.lowercased() }
                if match.confidence >= 0.7, currentMatch == nil, let s = suggestedFood { selectedFood = s }
            }
        } catch {}
        isLoading = false
    }
}

private struct FoodRow: View {
    let food: Food, isSelected: Bool
    var badge: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(food.name).font(.headline)
                        if let b = badge { CapsuleBadge(text: b, color: Color.themePrimary) }
                    }
                    if let n = food.nutrition {
                        Text("\(Int(n.calories)) kcal/100g").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.themePrimary) }
            }.padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(.pressFeedback)
    }
}
