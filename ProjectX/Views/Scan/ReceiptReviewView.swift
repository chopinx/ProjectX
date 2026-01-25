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
        guard !hasExtracted else { return }
        isLoading = true
        errorMessage = nil

        guard let service = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "Please configure your API key in Settings."
            isLoading = false
            return
        }

        do {
            let receipt: ExtractedReceipt
            switch source {
            case .image(let image):
                receipt = try await service.extractReceipt(from: image)
            case .text(let text):
                receipt = try await service.extractReceipt(from: text)
            }
            extractedItems = receipt.items
            if let name = receipt.storeName, !name.isEmpty { storeName = name }
            hasExtracted = true
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        isLoading = false
    }

    @MainActor
    func retryExtraction() async {
        hasExtracted = false
        await extractItemsIfNeeded()
    }

    func deleteItems(at offsets: IndexSet) {
        for index in offsets { foodLinks.removeValue(forKey: extractedItems[index].id) }
        extractedItems.remove(atOffsets: offsets)
    }

    func updateItem(_ item: ExtractedReceiptItem, with updated: ExtractedReceiptItem) {
        if let index = extractedItems.firstIndex(where: { $0.id == item.id }) {
            extractedItems[index] = updated
        }
    }

    func linkFood(_ food: Food?, to item: ExtractedReceiptItem) {
        if let food { foodLinks[item.id] = food }
        else { foodLinks.removeValue(forKey: item.id) }
    }

    var totalPrice: Double { extractedItems.reduce(0) { $0 + $1.price } }
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
    @State private var itemToDelete: ExtractedReceiptItem?

    private let onDismiss: (() -> Void)?

    // Init with external ViewModel (from ScanFlowManager)
    init(viewModel: ReceiptReviewViewModel, onDismiss: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDismiss = onDismiss
    }

    // Init creating own ViewModel (for ContentView imports)
    init(text: String, settings: AppSettings) {
        _viewModel = State(initialValue: ReceiptReviewViewModel(source: .text(text), settings: settings))
        self.onDismiss = nil
    }

    init(image: UIImage, settings: AppSettings) {
        _viewModel = State(initialValue: ReceiptReviewViewModel(source: .image(image), settings: settings))
        self.onDismiss = nil
    }

    var body: some View {
        Group {
            if viewModel.isLoading { loadingView }
            else if let error = viewModel.errorMessage { errorView(error) }
            else { reviewForm }
        }
        .navigationTitle("Review Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { onDismiss?(); dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Trip", action: saveTrip)
                    .disabled(viewModel.isLoading || viewModel.extractedItems.isEmpty)
            }
        }
        .task(id: "extract") {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            await viewModel.extractItemsIfNeeded()
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ReceiptItemEditSheet(item: item) { updated in
                    viewModel.updateItem(item, with: updated)
                    editingItem = nil
                }
            }
        }
        .sheet(item: $matchingItem) { item in
            NavigationStack {
                FoodMatchingSheet(item: item, foods: foods, currentMatch: viewModel.foodLinks[item.id]) { food in
                    viewModel.linkFood(food, to: item)
                    matchingItem = nil
                }
            }
        }
        .alert("Save Error", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: { Text("Failed to save the grocery trip.") }
        .deleteConfirmation("Remove Item?", item: $itemToDelete, message: { item in
            "Remove \"\(item.name)\" from this receipt?"
        }) { item in
            if let index = viewModel.extractedItems.firstIndex(where: { $0.id == item.id }) {
                withAnimation { viewModel.deleteItems(at: IndexSet(integer: index)) }
            }
        }
    }

    private var loadingView: some View {
        LoadingStateView(message: "Extracting items...")
    }

    private func errorView(_ message: String) -> some View {
        ErrorStateView("Extraction Failed", message: message) {
            Task { await viewModel.retryExtraction() }
        }
    }

    private var reviewForm: some View {
        Form {
            if case .image(let image) = viewModel.source {
                Section("Receipt Image") {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            Section("Trip Info") {
                DatePicker("Date", selection: Binding(get: { viewModel.tripDate }, set: { viewModel.tripDate = $0 }), displayedComponents: .date)
                TextField("Store (optional)", text: Binding(get: { viewModel.storeName }, set: { viewModel.storeName = $0 }))
            }
            Section {
                if viewModel.extractedItems.isEmpty {
                    VStack(spacing: 8) {
                        Text("No items found")
                            .foregroundStyle(.secondary)
                        Text("The receipt may be unclear or empty")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                } else {
                    ForEach(viewModel.extractedItems) { item in
                        ReceiptItemRow(item: item, linkedFood: viewModel.foodLinks[item.id], onEdit: { editingItem = item }, onMatch: { matchingItem = item })
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) { itemToDelete = item } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                HStack {
                    Text("Extracted Items")
                    Spacer()
                    if !viewModel.extractedItems.isEmpty {
                        Text("\(viewModel.extractedItems.count) item\(viewModel.extractedItems.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if !viewModel.extractedItems.isEmpty {
                    Text("Swipe left to remove items. Tap Link to connect items to your Food Bank for nutrition tracking.")
                        .font(.caption)
                }
            }
            if !viewModel.extractedItems.isEmpty {
                Section {
                    HStack { Text("Total").fontWeight(.semibold); Spacer(); Text(String(format: "%.2f", viewModel.totalPrice)).fontWeight(.semibold) }
                }
            }
        }
    }

    private func saveTrip() {
        let trip = GroceryTrip(date: viewModel.tripDate, storeName: viewModel.storeName.isEmpty ? nil : viewModel.storeName)
        context.insert(trip)
        for item in viewModel.extractedItems {
            let purchased = PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: viewModel.foodLinks[item.id])
            purchased.trip = trip
            trip.items.append(purchased)
        }
        do {
            try context.save()
            onDismiss?()
            dismiss()
        } catch { showingSaveError = true }
    }
}
