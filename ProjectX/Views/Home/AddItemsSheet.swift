import SwiftUI
import SwiftData

struct AddItemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Food.name) private var foods: [Food]
    let onItemsExtracted: ([ExtractedReceiptItem]) -> Void

    @State private var mode: InputMode = .options
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImages: [UIImage] = []
    @State private var inputText = ""
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var settings = AppSettings()

    // Review mode state
    @State private var extractedItems: [ExtractedReceiptItem] = []
    @State private var editingIndex: Int?

    enum InputMode { case options, photos, text, review }

    var body: some View {
        NavigationStack {
            Group {
                if isExtracting {
                    LoadingStateView(message: "Extracting items...")
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    switch mode {
                    case .options: optionsView
                    case .photos: photosView
                    case .text: textInputView
                    case .review: reviewView
                    }
                }
            }
            .navigationTitle(mode == .review ? "Review Items" : "Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(mode == .review ? "Back" : "Cancel") {
                        if mode == .review {
                            mode = capturedImages.isEmpty ? .text : .photos
                            extractedItems.removeAll()
                        } else {
                            dismiss()
                        }
                    }
                }
                if mode == .review {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            onItemsExtracted(extractedItems)
                            dismiss()
                        }
                        .disabled(extractedItems.isEmpty)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(sourceType: .camera, onImageCaptured: { capturedImages.append($0); showCamera = false }, onCancel: { showCamera = false })
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                MultiPhotoPicker(maxSelection: 10, onImagesPicked: { capturedImages.append(contentsOf: $0); showPhotoPicker = false }, onCancel: { showPhotoPicker = false })
            }
            .sheet(item: $editingIndex) { index in
                NavigationStack {
                    ExtractedItemEditView(item: extractedItems[index], foods: foods) { updated in
                        extractedItems[index] = updated
                        editingIndex = nil
                    }
                }
            }
        }
    }

    private var optionsView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "cart.badge.plus").font(.system(size: 80)).foregroundStyle(Color.themePrimary)
            VStack(spacing: 8) {
                Text("Add Items").font(.title2).fontWeight(.semibold)
                Text("Take photos of receipt, choose from library, or enter items manually")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button { mode = .photos; showCamera = true } label: {
                    Label("Take Photos", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(Color.themePrimary)
                Button { mode = .photos; showPhotoPicker = true } label: {
                    Label("Choose Photos", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(Color.themePrimary)
                Button { mode = .text } label: {
                    Label("Enter / Speak Items", systemImage: "text.alignleft").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(Color.themePrimary)
            }.padding(.horizontal, 24)
            Spacer()
        }
        .padding()
    }

    private var photosView: some View {
        VStack(spacing: 16) {
            if capturedImages.isEmpty {
                VStack(spacing: 16) {
                    Text("No photos yet").foregroundStyle(.secondary)
                    HStack(spacing: 16) {
                        Button { showCamera = true } label: {
                            Label("Camera", systemImage: "camera").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                        Button { showPhotoPicker = true } label: {
                            Label("Library", systemImage: "photo").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                    }
                    Button("Back") { mode = .options }.font(.caption)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(capturedImages.indices, id: \.self) { i in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: capturedImages[i]).resizable().scaledToFill()
                                    .frame(width: 100, height: 130).clipShape(RoundedRectangle(cornerRadius: 8))
                                Button { capturedImages.remove(at: i) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white, .red)
                                }.offset(x: 6, y: -6)
                            }
                        }
                        Button { showCamera = true } label: {
                            VStack { Image(systemName: "camera.fill"); Text("Add").font(.caption) }
                                .frame(width: 70, height: 130).background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                        Button { showPhotoPicker = true } label: {
                            VStack { Image(systemName: "photo.badge.plus"); Text("Add").font(.caption) }
                                .frame(width: 70, height: 130).background(Color(.tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain)
                    }.padding(.horizontal)
                }
                Text("\(capturedImages.count) photo\(capturedImages.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Button("Clear") { capturedImages.removeAll() }.buttonStyle(.bordered)
                    Button("Extract Items") { Task { await extractFromPhotos() } }.buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
    }

    private var textInputView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Enter items (one per line or comma-separated)")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                VoiceInputButton(text: $inputText)
            }
            TextEditor(text: $inputText)
                .frame(minHeight: 150)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("Example: Milk 1L 3.50, Bread 500g 2.00, Apples 1kg 4.50")
                .font(.caption2).foregroundStyle(.tertiary)
            HStack(spacing: 16) {
                Button("Back") { mode = .options; inputText = "" }.buttonStyle(.bordered)
                Button("Extract Items") { Task { await extractFromText() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
    }

    private var reviewView: some View {
        List {
            Section {
                Text("Tap an item to edit details, link to food, or remove")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Extracted Items (\(extractedItems.count))") {
                ForEach(Array(extractedItems.enumerated()), id: \.element.id) { index, item in
                    Button { editingIndex = index } label: {
                        ExtractedItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            extractedItems.remove(at: index)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ErrorStateView("Extraction Failed", message: message, retryAction: nil)
            HStack(spacing: 16) {
                Button("Start Over") { mode = .options; capturedImages.removeAll(); inputText = ""; errorMessage = nil }
                    .buttonStyle(.bordered)
                Button("Retry") { errorMessage = nil; Task { capturedImages.isEmpty ? await extractFromText() : await extractFromPhotos() } }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }

    private func extractFromPhotos() async {
        guard !capturedImages.isEmpty else { return }
        isExtracting = true
        errorMessage = nil
        do {
            let ocr = OCRService()
            var allText = ""
            for (i, image) in capturedImages.enumerated() {
                let text = try await ocr.extractText(from: image)
                allText += (i > 0 ? "\n\n" : "") + text
            }
            guard let service = LLMServiceFactory.create(settings: settings) else { throw LLMError.invalidAPIKey }
            let receipt = try await service.extractReceipt(from: allText, filterBabyFood: settings.filterBabyFood)
            extractedItems = receipt.items
            mode = .review
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed: \(error.localizedDescription)"
        }
        isExtracting = false
    }

    private func extractFromText() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isExtracting = true
        errorMessage = nil
        do {
            guard let service = LLMServiceFactory.create(settings: settings) else { throw LLMError.invalidAPIKey }
            let receipt = try await service.extractReceipt(from: inputText, filterBabyFood: settings.filterBabyFood)
            extractedItems = receipt.items
            mode = .review
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed: \(error.localizedDescription)"
        }
        isExtracting = false
    }
}

// MARK: - Extracted Item Row

private struct ExtractedItemRow: View {
    let item: ExtractedReceiptItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline)
                HStack(spacing: 8) {
                    Label("\(Int(item.quantityGrams))g", systemImage: "scalemass")
                    Label(String(format: "%.2f", item.price), systemImage: "dollarsign.circle")
                }
                .font(.caption).foregroundStyle(.secondary)
                Text(item.subcategory ?? item.category)
                    .font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Extracted Item Edit View

private struct ExtractedItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: String
    @State private var price: String
    @State private var category: String
    @State private var subcategory: String?

    private let originalItem: ExtractedReceiptItem
    private let foods: [Food]
    private let onSave: (ExtractedReceiptItem) -> Void

    init(item: ExtractedReceiptItem, foods: [Food], onSave: @escaping (ExtractedReceiptItem) -> Void) {
        self.originalItem = item
        self.foods = foods
        self.onSave = onSave
        _name = State(initialValue: item.name)
        _quantity = State(initialValue: String(format: "%.0f", item.quantityGrams))
        _price = State(initialValue: String(format: "%.2f", item.price))
        _category = State(initialValue: item.category)
        _subcategory = State(initialValue: item.subcategory)
    }

    var body: some View {
        Form {
            Section("Item Details") {
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
            }

            Section("Category") {
                Text(subcategory ?? category).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    guard let qty = Double(quantity), let prc = Double(price) else { return }
                    var updated = originalItem
                    updated.name = name
                    updated.quantityGrams = qty
                    updated.price = prc
                    onSave(updated)
                }
                .disabled(name.isEmpty || Double(quantity) == nil || Double(price) == nil)
            }
        }
    }
}

// MARK: - Int Identifiable Extension

extension Int: @retroactive Identifiable {
    public var id: Int { self }
}
