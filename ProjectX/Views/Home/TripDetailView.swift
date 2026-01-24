import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var date: Date
    @State private var storeName: String
    @State private var items: [PurchasedItem]
    @State private var editingItem: PurchasedItem?
    @State private var showingAddItem = false

    private var existingTrip: GroceryTrip?
    private var isNewTrip: Bool { existingTrip == nil }

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
                    Text("No items yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        Button {
                            editingItem = item
                        } label: {
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
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteItems)
                }

                Button {
                    showingAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus.circle")
                }
            } header: {
                Text("Items")
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
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func save() {
        let trip: GroceryTrip
        if let existingTrip {
            trip = existingTrip
            trip.date = date
            trip.storeName = storeName.isEmpty ? nil : storeName
            trip.updatedAt = .now
            trip.items.removeAll()
        } else {
            trip = GroceryTrip(date: date, storeName: storeName.isEmpty ? nil : storeName)
            context.insert(trip)
        }

        for item in items {
            item.trip = trip
            trip.items.append(item)
        }

        try? context.save()
        dismiss()
    }
}
