import SwiftUI
import SwiftData

enum ReceiptSource {
    case image(UIImage)
    case text(String)
}

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    private let source: ReceiptSource

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var extractedItems: [ExtractedReceiptItem] = []
    @State private var foodLinks: [UUID: Food] = [:]
    @State private var editingItem: ExtractedReceiptItem?
    @State private var matchingItem: ExtractedReceiptItem?
    @State private var storeName = ""
    @State private var tripDate = Date()
    @State private var showingSaveError = false

    private let settings: AppSettings

    init(image: UIImage, settings: AppSettings) {
        self.source = .image(image)
        self.settings = settings
    }

    init(text: String, settings: AppSettings) {
        self.source = .text(text)
        self.settings = settings
    }

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else {
                reviewForm
            }
        }
        .navigationTitle("Review Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Trip", action: saveTrip)
                    .disabled(isLoading || extractedItems.isEmpty)
            }
        }
        .task {
            await extractItems()
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ReceiptItemEditSheet(item: item) { updatedItem in
                    if let index = extractedItems.firstIndex(where: { $0.id == item.id }) {
                        extractedItems[index] = updatedItem
                    }
                    editingItem = nil
                }
            }
        }
        .sheet(item: $matchingItem) { item in
            NavigationStack {
                FoodMatchingSheet(
                    item: item,
                    foods: foods,
                    currentMatch: foodLinks[item.id]
                ) { food in
                    if let food {
                        foodLinks[item.id] = food
                    } else {
                        foodLinks.removeValue(forKey: item.id)
                    }
                    matchingItem = nil
                }
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: {
            Text("Failed to save the grocery trip. Please try again.")
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Extracting items...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Extraction Failed")
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                Task { await extractItems() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var reviewForm: some View {
        Form {
            if case .image(let image) = source {
                Section("Receipt Image") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Section("Trip Info") {
                DatePicker("Date", selection: $tripDate, displayedComponents: .date)
                TextField("Store (optional)", text: $storeName)
            }

            Section {
                if extractedItems.isEmpty {
                    Text("No items found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(extractedItems) { item in
                        ReceiptItemRow(
                            item: item,
                            linkedFood: foodLinks[item.id],
                            onEdit: { editingItem = item },
                            onMatch: { matchingItem = item }
                        )
                    }
                    .onDelete(perform: deleteItems)
                }
            } header: {
                HStack {
                    Text("Extracted Items")
                    Spacer()
                    Text("\(extractedItems.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !extractedItems.isEmpty {
                Section {
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.2f", totalPrice))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private var totalPrice: Double {
        extractedItems.reduce(0) { $0 + $1.price }
    }

    private func extractItems() async {
        isLoading = true
        errorMessage = nil

        guard let service = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "Please configure your API key in Settings."
            isLoading = false
            return
        }

        do {
            switch source {
            case .image(let image):
                extractedItems = try await service.extractReceiptItems(from: image)
            case .text(let text):
                extractedItems = try await service.extractReceiptItems(from: text)
            }
            isLoading = false
        } catch let error as LLMError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = extractedItems[index]
            foodLinks.removeValue(forKey: item.id)
        }
        extractedItems.remove(atOffsets: offsets)
    }

    private func saveTrip() {
        let trip = GroceryTrip(
            date: tripDate,
            storeName: storeName.isEmpty ? nil : storeName
        )
        context.insert(trip)

        for extractedItem in extractedItems {
            let purchasedItem = PurchasedItem(
                name: extractedItem.name,
                quantity: extractedItem.quantityGrams,
                price: extractedItem.price,
                food: foodLinks[extractedItem.id]
            )
            purchasedItem.trip = trip
            trip.items.append(purchasedItem)
        }

        do {
            try context.save()
            dismiss()
        } catch {
            showingSaveError = true
        }
    }
}
