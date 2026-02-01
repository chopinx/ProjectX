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
    private let onSavePurchased: ((PurchasedItem) -> Void)?
    private let onSaveExtracted: ((ExtractedReceiptItem) -> Void)?
    private let originalExtracted: ExtractedReceiptItem?

    // Init for PurchasedItem (existing flow)
    init(item: PurchasedItem?, foods: [Food], onSave: @escaping (PurchasedItem) -> Void) {
        self.existingItem = item
        self.foods = foods
        self.onSavePurchased = onSave
        self.onSaveExtracted = nil
        self.originalExtracted = nil
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item != nil ? String(format: "%.0f", item!.quantity) : "")
        _price = State(initialValue: item != nil ? String(format: "%.2f", item!.price) : "")
        _selectedFood = State(initialValue: item?.food)
        _isSkipped = State(initialValue: item?.isSkipped ?? false)
    }

    // Init for ExtractedReceiptItem (review flow)
    init(item: ExtractedReceiptItem, foods: [Food], onSave: @escaping (ExtractedReceiptItem) -> Void) {
        self.existingItem = nil
        self.foods = foods
        self.onSavePurchased = nil
        self.onSaveExtracted = onSave
        self.originalExtracted = item
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: String(format: "%.0f", item.quantityGrams))
        _price = State(initialValue: String(format: "%.2f", item.price))
        _selectedFood = State(initialValue: item.linkedFoodId.flatMap { id in foods.first { $0.id == id } })
        _isSkipped = State(initialValue: false)
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

            // Only show skip toggle for PurchasedItem
            if onSavePurchased != nil {
                Section {
                    Toggle("Skip this item", isOn: $isSkipped)
                } footer: {
                    Text("Skipped items won't count toward nutrition totals")
                }
            }
        }
        .navigationTitle(existingItem == nil && originalExtracted == nil ? "Add Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { saveItem() }
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

    private func saveItem() {
        guard let qty = Double(quantity), let prc = Double(price) else { return }

        if let onSave = onSavePurchased {
            // Save as PurchasedItem
            let item = existingItem ?? PurchasedItem(name: name, quantity: qty, price: prc)
            item.name = name
            item.quantity = qty
            item.price = prc
            item.food = selectedFood
            item.isSkipped = isSkipped
            onSave(item)
        } else if let onSave = onSaveExtracted, var extracted = originalExtracted {
            // Save as ExtractedReceiptItem
            extracted.name = name
            extracted.quantityGrams = qty
            extracted.price = prc
            extracted.linkedFoodId = selectedFood?.id
            onSave(extracted)
        }
    }
}
