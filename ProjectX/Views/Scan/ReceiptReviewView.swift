import SwiftUI
import SwiftData

enum ReceiptSource {
    case image(UIImage)
    case text(String)
}

// MARK: - View Model

@Observable
final class ReceiptReviewViewModel {
    var isLoading = true
    var errorMessage: String?
    var extractedItems: [ExtractedReceiptItem] = []
    var foodLinks: [UUID: Food] = [:]
    var storeName = ""
    var tripDate = Date()
    var hasExtracted = false

    let source: ReceiptSource
    let settings: AppSettings

    init(source: ReceiptSource, settings: AppSettings) {
        self.source = source
        self.settings = settings
    }

    @MainActor
    func extractItemsIfNeeded() async {
        // Only extract once - don't re-extract when returning from background
        guard !hasExtracted else { return }

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
            hasExtracted = true
            isLoading = false
        } catch let error as LLMError {
            errorMessage = error.errorDescription
            isLoading = false
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            isLoading = false
        }
    }

    @MainActor
    func retryExtraction() async {
        hasExtracted = false
        await extractItemsIfNeeded()
    }

    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = extractedItems[index]
            foodLinks.removeValue(forKey: item.id)
        }
        extractedItems.remove(atOffsets: offsets)
    }

    func updateItem(_ item: ExtractedReceiptItem, with updatedItem: ExtractedReceiptItem) {
        if let index = extractedItems.firstIndex(where: { $0.id == item.id }) {
            extractedItems[index] = updatedItem
        }
    }

    func linkFood(_ food: Food?, to item: ExtractedReceiptItem) {
        if let food {
            foodLinks[item.id] = food
        } else {
            foodLinks.removeValue(forKey: item.id)
        }
    }

    var totalPrice: Double {
        extractedItems.reduce(0) { $0 + $1.price }
    }
}

// MARK: - View

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var viewModel: ReceiptReviewViewModel
    @State private var editingItem: ExtractedReceiptItem?
    @State private var matchingItem: ExtractedReceiptItem?
    @State private var showingSaveError = false

    init(image: UIImage, settings: AppSettings) {
        _viewModel = State(initialValue: ReceiptReviewViewModel(source: .image(image), settings: settings))
    }

    init(text: String, settings: AppSettings) {
        _viewModel = State(initialValue: ReceiptReviewViewModel(source: .text(text), settings: settings))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let error = viewModel.errorMessage {
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
                    .disabled(viewModel.isLoading || viewModel.extractedItems.isEmpty)
            }
        }
        .task(id: "extract") {
            // Small delay to ensure view is fully loaded after navigation
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await viewModel.extractItemsIfNeeded()
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ReceiptItemEditSheet(item: item) { updatedItem in
                    viewModel.updateItem(item, with: updatedItem)
                    editingItem = nil
                }
            }
        }
        .sheet(item: $matchingItem) { item in
            NavigationStack {
                FoodMatchingSheet(
                    item: item,
                    foods: foods,
                    currentMatch: viewModel.foodLinks[item.id]
                ) { food in
                    viewModel.linkFood(food, to: item)
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
                Task { await viewModel.retryExtraction() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var reviewForm: some View {
        Form {
            if case .image(let image) = viewModel.source {
                Section("Receipt Image") {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Section("Trip Info") {
                DatePicker("Date", selection: $viewModel.tripDate, displayedComponents: .date)
                TextField("Store (optional)", text: $viewModel.storeName)
            }

            Section {
                if viewModel.extractedItems.isEmpty {
                    Text("No items found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.extractedItems) { item in
                        ReceiptItemRow(
                            item: item,
                            linkedFood: viewModel.foodLinks[item.id],
                            onEdit: { editingItem = item },
                            onMatch: { matchingItem = item }
                        )
                    }
                    .onDelete(perform: viewModel.deleteItems)
                }
            } header: {
                HStack {
                    Text("Extracted Items")
                    Spacer()
                    Text("\(viewModel.extractedItems.count) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.extractedItems.isEmpty {
                Section {
                    HStack {
                        Text("Total")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.2f", viewModel.totalPrice))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func saveTrip() {
        let trip = GroceryTrip(
            date: viewModel.tripDate,
            storeName: viewModel.storeName.isEmpty ? nil : viewModel.storeName
        )
        context.insert(trip)

        for extractedItem in viewModel.extractedItems {
            let purchasedItem = PurchasedItem(
                name: extractedItem.name,
                quantity: extractedItem.quantityGrams,
                price: extractedItem.price,
                food: viewModel.foodLinks[extractedItem.id]
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
