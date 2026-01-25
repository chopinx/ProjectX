import SwiftUI
import SwiftData

enum ReceiptSource { case image(UIImage), text(String) }
struct SuggestedMatch: Equatable { let food: Food; let confidence: Double }

// MARK: - Draft

fileprivate struct ReceiptDraft: Codable {
    var items: [ExtractedReceiptItem], foodLinkIds: [UUID: UUID], suggestedIds: [UUID: UUID], storeName: String, tripDate: Date, imageData: Data?
    static let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("receipt_draft.json")
    static func load() -> ReceiptDraft? { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Self.self, from: $0) } }
    func save() { try? JSONEncoder().encode(self).write(to: Self.url) }
    static func clear() { try? FileManager.default.removeItem(at: url) }
}

// MARK: - ViewModel

@Observable
final class ReceiptReviewViewModel {
    var isLoading = true
    var isMatching = false
    var errorMessage: String?
    var extractedItems: [ExtractedReceiptItem] = []
    var foodLinks: [UUID: Food] = [:]
    var suggestedMatches: [UUID: SuggestedMatch] = [:]
    var storeName = ""
    var tripDate = Date()
    private var hasExtracted = false
    let source: ReceiptSource
    let settings: AppSettings

    init(source: ReceiptSource, settings: AppSettings) { self.source = source; self.settings = settings }

    @MainActor func extract() async {
        guard !hasExtracted else { return }
        isLoading = true; errorMessage = nil
        guard let svc = LLMServiceFactory.create(settings: settings) else { errorMessage = "Configure API key in Settings."; isLoading = false; return }
        do {
            let r: ExtractedReceipt
            switch source { case .image(let img): r = try await svc.extractReceipt(from: img); case .text(let txt): r = try await svc.extractReceipt(from: txt) }
            extractedItems = r.items
            if let n = r.storeName, !n.isEmpty { storeName = n }
            if let d = r.parsedDate { tripDate = d }
            hasExtracted = true
        } catch let e as LLMError { errorMessage = e.errorDescription } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }

    @MainActor func autoMatch(_ foods: [Food]) async {
        guard !extractedItems.isEmpty, !foods.isEmpty, let svc = LLMServiceFactory.create(settings: settings) else { return }
        isMatching = true
        let byName = Dictionary(uniqueKeysWithValues: foods.map { ($0.name.lowercased(), $0) })
        for item in extractedItems where foodLinks[item.id] == nil && suggestedMatches[item.id] == nil {
            if let m = try? await svc.matchFood(itemName: item.name, existingFoods: foods.map(\.name)),
               let name = m.foodName, let food = byName[name.lowercased()] {
                if m.confidence >= 0.95 && food.nutrition != nil { foodLinks[item.id] = food }
                else if m.confidence >= 0.90 { suggestedMatches[item.id] = SuggestedMatch(food: food, confidence: m.confidence) }
            }
        }
        isMatching = false
    }

    func confirm(_ id: UUID) { if let s = suggestedMatches.removeValue(forKey: id) { foodLinks[id] = s.food } }
    func dismiss(_ id: UUID) { suggestedMatches.removeValue(forKey: id) }
    @MainActor func retry() async { hasExtracted = false; await extract() }
    func delete(at o: IndexSet) { o.forEach { foodLinks.removeValue(forKey: extractedItems[$0].id); suggestedMatches.removeValue(forKey: extractedItems[$0].id) }; extractedItems.remove(atOffsets: o) }
    func update(_ item: ExtractedReceiptItem, _ updated: ExtractedReceiptItem) { if let i = extractedItems.firstIndex(where: { $0.id == item.id }) { extractedItems[i] = updated } }
    func link(_ food: Food?, _ item: ExtractedReceiptItem) { suggestedMatches.removeValue(forKey: item.id); if let f = food { foodLinks[item.id] = f } else { foodLinks.removeValue(forKey: item.id) } }
    var total: Double { extractedItems.reduce(0) { $0 + $1.price } }

    fileprivate func restore(_ d: ReceiptDraft, _ foods: [Food]) {
        extractedItems = d.items; storeName = d.storeName; tripDate = d.tripDate
        let byId = Dictionary(uniqueKeysWithValues: foods.map { ($0.id, $0) })
        foodLinks = d.foodLinkIds.compactMapValues { byId[$0] }
        suggestedMatches = d.suggestedIds.compactMapValues { byId[$0].map { SuggestedMatch(food: $0, confidence: 0.9) } }
        hasExtracted = true; isLoading = false
    }

    fileprivate func toDraft() -> ReceiptDraft {
        ReceiptDraft(items: extractedItems, foodLinkIds: foodLinks.mapValues(\.id), suggestedIds: suggestedMatches.mapValues(\.food.id),
                     storeName: storeName, tripDate: tripDate, imageData: source.image?.jpegData(compressionQuality: 0.5))
    }
}

private extension ReceiptSource { var image: UIImage? { if case .image(let i) = self { return i }; return nil } }

// MARK: - View

struct ReceiptReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Environment(\.scenePhase) private var phase
    @Query(sort: \Food.name) private var foods: [Food]
    @State private var vm: ReceiptReviewViewModel
    @State private var editing: ExtractedReceiptItem?
    @State private var matching: ExtractedReceiptItem?
    @State private var deleting: IndexSet?
    @State private var saveError = false
    @State private var restored = false
    private let onDismiss: (() -> Void)?

    init(viewModel: ReceiptReviewViewModel, onDismiss: @escaping () -> Void) { _vm = State(initialValue: viewModel); self.onDismiss = onDismiss }
    init(text: String, settings: AppSettings) { _vm = State(initialValue: ReceiptReviewViewModel(source: .text(text), settings: settings)); onDismiss = nil }
    init(image: UIImage, settings: AppSettings) { _vm = State(initialValue: ReceiptReviewViewModel(source: .image(image), settings: settings)); onDismiss = nil }

    var body: some View {
        Group {
            if vm.isLoading { LoadingStateView(message: "Extracting items...") }
            else if let e = vm.errorMessage { ErrorStateView("Extraction Failed", message: e) { Task { await vm.retry() } } }
            else { form }
        }
        .navigationTitle("Review Receipt").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { ReceiptDraft.clear(); onDismiss?(); dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save Trip", action: save).disabled(vm.isLoading || vm.extractedItems.isEmpty) }
        }
        .task {
            if !restored, let d = ReceiptDraft.load(), !d.items.isEmpty { vm.restore(d, foods); restored = true }
            else { try? await Task.sleep(for: .milliseconds(100)); await vm.extract(); await vm.autoMatch(foods) }
        }
        .onChange(of: phase) { _, p in if p == .background || p == .inactive { vm.toDraft().save() } }
        .sheet(item: $editing) { i in NavigationStack { ReceiptItemEditSheet(item: i) { vm.update(i, $0); editing = nil } } }
        .sheet(item: $matching) { i in NavigationStack { FoodMatchingSheet(item: i, foods: foods, currentMatch: vm.foodLinks[i.id]) { vm.link($0, i); matching = nil } } }
        .alert("Save Error", isPresented: $saveError) { Button("OK") {} } message: { Text("Failed to save.") }
        .alert("Remove Item?", isPresented: .init(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Cancel", role: .cancel) { deleting = nil }
            Button("Remove", role: .destructive) { if let o = deleting { deleting = nil; vm.delete(at: o) } }
        } message: { if let o = deleting, let i = o.first, i < vm.extractedItems.count { Text("Remove \"\(vm.extractedItems[i].name)\"?") } }
    }

    private var form: some View {
        Form {
            if let img = vm.source.image { Section("Receipt") { Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 200).clipShape(RoundedRectangle(cornerRadius: 8)) } }
            Section("Trip Info") {
                DatePicker("Date", selection: Binding(get: { vm.tripDate }, set: { vm.tripDate = $0 }), displayedComponents: .date)
                TextField("Store", text: Binding(get: { vm.storeName }, set: { vm.storeName = $0 }))
            }
            Section {
                if vm.extractedItems.isEmpty { Text("No items found").foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical) }
                else { ForEach(vm.extractedItems) { item in
                    ReceiptItemRow(item: item, linked: vm.foodLinks[item.id], suggested: vm.suggestedMatches[item.id],
                                   onEdit: { editing = item }, onMatch: { matching = item }, onConfirm: { vm.confirm(item.id) }, onDismiss: { vm.dismiss(item.id) })
                }.onDelete { deleting = $0 } }
            } header: { HStack { Text("Items"); if vm.isMatching { ProgressView().scaleEffect(0.7) }; Spacer(); Text("\(vm.extractedItems.count)").font(.caption).foregroundStyle(.secondary) } }
            if !vm.extractedItems.isEmpty { Section { HStack { Text("Total").bold(); Spacer(); Text(String(format: "%.2f", vm.total)).bold() } } }
        }
    }

    private func save() {
        let trip = GroceryTrip(date: vm.tripDate, storeName: vm.storeName.isEmpty ? nil : vm.storeName)
        ctx.insert(trip)
        for item in vm.extractedItems { let p = PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: vm.foodLinks[item.id]); p.trip = trip; trip.items.append(p) }
        do { try ctx.save(); ReceiptDraft.clear(); onDismiss?(); dismiss() } catch { saveError = true }
    }
}
