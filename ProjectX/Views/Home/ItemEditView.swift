import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: String
    @State private var price: String
    @State private var selectedFood: Food?
    @State private var isSkipped: Bool

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
            Section("Item Details") {
                TextField("Name", text: $name)
                HStack {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
            }

            Section("Link to Food") {
                Picker("Food", selection: $selectedFood) {
                    Text("None").tag(nil as Food?)
                    ForEach(foods) { food in
                        Text(food.name).tag(food as Food?)
                    }
                }

                if let food = selectedFood, let nutrition = food.nutrition {
                    let qty = Double(quantity) ?? 0
                    let scaled = nutrition.scaled(byGrams: qty)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated nutrition for \(Int(qty))g:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(scaled.calories)) kcal, \(Int(scaled.protein))g protein")
                            .font(.caption)
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
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let item = existingItem ?? PurchasedItem(
                        name: name,
                        quantity: Double(quantity) ?? 0,
                        price: Double(price) ?? 0
                    )
                    item.name = name
                    item.quantity = Double(quantity) ?? 0
                    item.price = Double(price) ?? 0
                    item.food = selectedFood
                    item.isSkipped = isSkipped
                    onSave(item)
                }
                .disabled(name.isEmpty || quantity.isEmpty)
            }
        }
    }
}
