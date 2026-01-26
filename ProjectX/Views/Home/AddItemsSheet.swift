import SwiftUI

struct AddItemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onItemsExtracted: ([ExtractedReceiptItem]) -> Void

    @State private var mode: InputMode = .options
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImages: [UIImage] = []
    @State private var inputText = ""
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var settings = AppSettings()

    enum InputMode { case options, photos, text }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if isExtracting {
                    LoadingStateView(message: "Extracting items...")
                } else if let error = errorMessage {
                    errorView(error)
                } else {
                    switch mode {
                    case .options: optionsView
                    case .photos: photosView
                    case .text: textInputView
                    }
                }
            }
            .padding()
            .navigationTitle("Add Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(sourceType: .camera, onImageCaptured: { capturedImages.append($0); showCamera = false }, onCancel: { showCamera = false })
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                MultiPhotoPicker(maxSelection: 10, onImagesPicked: { capturedImages.append(contentsOf: $0); showPhotoPicker = false }, onCancel: { showPhotoPicker = false })
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
            onItemsExtracted(receipt.items)
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
            onItemsExtracted(receipt.items)
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed: \(error.localizedDescription)"
        }
        isExtracting = false
    }
}
