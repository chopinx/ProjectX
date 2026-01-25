import SwiftUI
import SwiftData

enum ReceiptSource { case image(UIImage), text(String) }

@Observable
final class ReceiptReviewViewModel {
    var isLoading = true
    var errorMessage: String?
    var extractedItems: [ExtractedReceiptItem] = []
    var foodLinks: [UUID: Food] = [:]
    var storeName = ""
    var tripDate = Date()
    private var hasExtracted = false

    let source: ReceiptSource
    let settings: AppSettings

    init(source: ReceiptSource, settings: AppSettings) { self.source = source; self.settings = settings }

    @MainActor
    func extractIfNeeded() async {
        guard !hasExtracted else { return }
        isLoading = true; errorMessage = nil
        guard let service = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "Please configure your API key in Settings."; isLoading = false; return
        }
        do {
            let receipt: ExtractedReceipt
            switch source {
            case .image(let img): receipt = try await service.extractReceipt(from: img)
            case .text(let txt): receipt = try await service.extractReceipt(from: txt)
            }
            extractedItems = receipt.items
            if let name = receipt.storeName, !name.isEmpty { storeName = name }
            hasExtracted = true
        } catch let e as LLMError { errorMessage = e.errorDescription }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    @MainActor func retry() async { hasExtracted = false; await extractIfNeeded() }
    func delete(at offsets: IndexSet) { offsets.forEach { foodLinks.removeValue(forKey: extractedItems[$0].id) }; extractedItems.remove(atOffsets: offsets) }
    func update(_ item: ExtractedReceiptItem, with updated: ExtractedReceiptItem) { if let i = extractedItems.firstIndex(where: { $0.id == item.id }) { extractedItems[i] = updated } }
    func link(_ food: Food?, to item: ExtractedReceiptItem) { if let food { foodLinks[item.id] = food } else { foodLinks.removeValue(forKey: item.id) } }
    var total: Double { extractedItems.reduce(0) { $0 + $1.price } }
}

private extension ReceiptSource {
    var image: UIImage? { if case .image(let img) = self { return img }; return nil }
}

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var vm: ReceiptReviewViewModel
    @State private var editingItem: ExtractedReceiptItem?
    @State private var matchingItem: ExtractedReceiptItem?
    @State private var showingSaveError = false
    @State private var deleteOffsets: IndexSet?

    private let onDismiss: (() -> Void)?

    init(viewModel: ReceiptReviewViewModel, onDismiss: @escaping () -> Void) { _vm = State(initialValue: viewModel); self.onDismiss = onDismiss }
    init(text: String, settings: AppSettings) { _vm = State(initialValue: ReceiptReviewViewModel(source: .text(text), settings: settings)); onDismiss = nil }
    init(image: UIImage, settings: AppSettings) { _vm = State(initialValue: ReceiptReviewViewModel(source: .image(image), settings: settings)); onDismiss = nil }

    var body: some View {
        Group {
            if vm.isLoading { LoadingStateView(message: "Extracting items...") }
            else if let error = vm.errorMessage { ErrorStateView("Extraction Failed", message: error) { Task { await vm.retry() } } }
            else { reviewForm }
        }
        .navigationTitle("Review Receipt").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { onDismiss?(); dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save Trip", action: saveTrip).disabled(vm.isLoading || vm.extractedItems.isEmpty) }
        }
        .task { try? await Task.sleep(for: .milliseconds(100)); await vm.extractIfNeeded() }
        .sheet(item: $editingItem) { item in NavigationStack { ReceiptItemEditSheet(item: item) { vm.update(item, with: $0); editingItem = nil } } }
        .sheet(item: $matchingItem) { item in NavigationStack { FoodMatchingSheet(item: item, foods: foods, currentMatch: vm.foodLinks[item.id]) { vm.link($0, to: item); matchingItem = nil } } }
        .alert("Save Error", isPresented: $showingSaveError) { Button("OK") {} } message: { Text("Failed to save the grocery trip.") }
        .alert("Remove Item?", isPresented: .init(get: { deleteOffsets != nil }, set: { if !$0 { deleteOffsets = nil } })) {
            Button("Cancel", role: .cancel) { deleteOffsets = nil }
            Button("Remove", role: .destructive) { if let o = deleteOffsets { deleteOffsets = nil; vm.delete(at: o) } }
        } message: { if let o = deleteOffsets, let i = o.first, i < vm.extractedItems.count { Text("Remove \"\(vm.extractedItems[i].name)\"?") } }
    }

    private var reviewForm: some View {
        Form {
            if let img = vm.source.image {
                Section("Receipt Image") { Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 8)) }
            }
            Section("Trip Info") {
                DatePicker("Date", selection: Binding(get: { vm.tripDate }, set: { vm.tripDate = $0 }), displayedComponents: .date)
                TextField("Store (optional)", text: Binding(get: { vm.storeName }, set: { vm.storeName = $0 }))
            }
            Section {
                if vm.extractedItems.isEmpty {
                    VStack(spacing: 8) { Text("No items found").foregroundStyle(.secondary); Text("The receipt may be unclear or empty").font(.caption).foregroundStyle(.tertiary) }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                } else {
                    ForEach(vm.extractedItems) { item in
                        ReceiptItemRow(item: item, linkedFood: vm.foodLinks[item.id], onEdit: { editingItem = item }, onMatch: { matchingItem = item })
                    }.onDelete { deleteOffsets = $0 }
                }
            } header: {
                HStack { Text("Extracted Items"); Spacer(); if !vm.extractedItems.isEmpty { Text("\(vm.extractedItems.count) item\(vm.extractedItems.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary) } }
            } footer: { if !vm.extractedItems.isEmpty { Text("Swipe left to remove. Tap Link for nutrition tracking.").font(.caption) } }
            if !vm.extractedItems.isEmpty {
                Section { HStack { Text("Total").fontWeight(.semibold); Spacer(); Text(String(format: "%.2f", vm.total)).fontWeight(.semibold) } }
            }
        }
    }

    private func saveTrip() {
        let trip = GroceryTrip(date: vm.tripDate, storeName: vm.storeName.isEmpty ? nil : vm.storeName)
        context.insert(trip)
        for item in vm.extractedItems {
            let purchased = PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: vm.foodLinks[item.id])
            purchased.trip = trip; trip.items.append(purchased)
        }
        do { try context.save(); onDismiss?(); dismiss() } catch { showingSaveError = true }
    }
}
