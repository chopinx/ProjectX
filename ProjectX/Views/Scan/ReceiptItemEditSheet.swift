import SwiftUI

struct ReceiptItemEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantityGrams: String
    @State private var price: String
    @State private var category: String

    private let originalItem: ExtractedReceiptItem
    private let onSave: (ExtractedReceiptItem) -> Void

    init(item: ExtractedReceiptItem, onSave: @escaping (ExtractedReceiptItem) -> Void) {
        self.originalItem = item
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _quantityGrams = State(initialValue: String(format: "%.0f", item.quantityGrams))
        _price = State(initialValue: String(format: "%.2f", item.price))
        _category = State(initialValue: item.category)
    }

    var body: some View {
        Form {
            Section("Item Details") {
                TextField("Name", text: $name)
                UnitTextField(placeholder: "Quantity", value: $quantityGrams, unit: "g", keyboard: .numberPad)
                UnitTextField(placeholder: "Price", value: $price, unit: "")
            }

            Section("Category") {
                Picker("Category", selection: $category) {
                    ForEach(FoodMainCategory.allCases) { main in
                        Label(main.displayName, systemImage: main.icon).tag(main.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var updatedItem = originalItem
                    updatedItem.name = name
                    updatedItem.quantityGrams = Double(quantityGrams) ?? originalItem.quantityGrams
                    updatedItem.price = Double(price) ?? originalItem.price
                    updatedItem.category = category
                    onSave(updatedItem)
                }
                .disabled(name.isEmpty)
            }
        }
    }
}
