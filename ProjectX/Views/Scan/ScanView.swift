import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ScanView: View {
    var settings: AppSettings

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showTextInput = false
    @State private var showScanTypeSelection = false
    @State private var receiptText = ""
    @State private var pendingOCRText: String?
    @State private var showReviewFromText = false
    @State private var showNutritionFromText = false
    @State private var isProcessingOCR = false
    @State private var errorMessage: String?

    enum ScanType: String, CaseIterable, Identifiable {
        case receipt = "Receipt"
        case nutritionLabel = "Nutrition Label"

        var id: String { rawValue }
        var icon: String { self == .receipt ? "doc.text.viewfinder" : "chart.bar.doc.horizontal" }
        var description: String { self == .receipt ? "Extract grocery items and prices" : "Extract nutrition information" }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 24) {
                    Spacer()
                    if !settings.isConfigured { configurationRequiredView }
                    else { scanOptionsView }
                    Spacer()
                }
                if isProcessingOCR { ocrProcessingOverlay }
            }
            .navigationTitle("Scan")
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(sourceType: .camera, onImageCaptured: handleImageCaptured, onCancel: { showCamera = false })
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                CameraView(sourceType: .photoLibrary, onImageCaptured: handleImageCaptured, onCancel: { showPhotoPicker = false })
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(allowedTypes: [.pdf, .image]) { url in
                    showDocumentPicker = false
                    handleDocumentPicked(url)
                }
            }
            .sheet(isPresented: $showTextInput) {
                TextInputSheet(
                    text: $receiptText,
                    title: "Enter Text",
                    placeholder: "Paste or type your receipt/label text below",
                    example: "Example:\nApples 1kg 2.99\nMilk 1L 1.49\nBread 500g 2.29",
                    buttonTitle: "Continue"
                ) {
                    showTextInput = false
                    if !receiptText.isEmpty {
                        pendingOCRText = receiptText
                        showScanTypeSelection = true
                    }
                }
            }
            .sheet(isPresented: $showScanTypeSelection) {
                ScanTypeSelectionSheet(
                    onSelect: { type in
                        showScanTypeSelection = false
                        if type == .receipt { showReviewFromText = true }
                        else { showNutritionFromText = true }
                    },
                    onCancel: { showScanTypeSelection = false; pendingOCRText = nil }
                )
                .presentationDetents([.medium])
            }
            .navigationDestination(isPresented: $showReviewFromText) {
                if let text = pendingOCRText { ReceiptReviewView(text: text, settings: settings) }
            }
            .navigationDestination(isPresented: $showNutritionFromText) {
                if let text = pendingOCRText { NutritionLabelResultView(text: text, settings: settings) }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var configurationRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill").font(.system(size: 60)).foregroundStyle(.orange)
            Text("API Key Required").font(.title2).fontWeight(.semibold)
            Text("Please configure your API key in Settings to enable scanning.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
        }
    }

    private var scanOptionsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder").font(.system(size: 80)).foregroundStyle(.blue)
            VStack(spacing: 8) {
                Text("Scan Receipt or Label").font(.title2).fontWeight(.semibold)
                Text("Take a photo, import a file, or enter text").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Button { showCamera = true } label: { Label("Take Photo", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                Button { showPhotoPicker = true } label: { Label("Choose from Library", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                Button { showDocumentPicker = true } label: { Label("Import PDF or Image", systemImage: "doc.badge.plus").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                Button { receiptText = ""; showTextInput = true } label: { Label("Enter Text", systemImage: "text.alignleft").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 48)
        }
    }

    private var ocrProcessingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Extracting text...").font(.headline).foregroundStyle(.white)
            }
            .padding(32).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func handleImageCaptured(_ image: UIImage) {
        showCamera = false
        showPhotoPicker = false
        Task { await performOCR(from: .image(image)) }
    }

    private func handleDocumentPicked(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let data = try? Data(contentsOf: url) else { errorMessage = "Failed to read PDF file"; return }
            Task { await performOCR(from: .pdf(data)) }
        } else if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { errorMessage = "Failed to read image file"; return }
            Task { await performOCR(from: .image(image)) }
        } else {
            errorMessage = "Unsupported file type"
        }
    }

    private func performOCR(from source: ImportManager.ImportSource) async {
        isProcessingOCR = true
        defer { isProcessingOCR = false }
        do {
            pendingOCRText = try await ImportManager().processImport(source)
            showScanTypeSelection = true
        } catch {
            errorMessage = "Failed to extract text: \(error.localizedDescription)"
        }
    }
}

// MARK: - Scan Type Selection Sheet

struct ScanTypeSelectionSheet: View {
    let onSelect: (ScanView.ScanType) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("What would you like to extract?").font(.headline).padding(.top)
                VStack(spacing: 16) {
                    ForEach(ScanView.ScanType.allCases) { type in
                        Button { onSelect(type) } label: {
                            HStack(spacing: 16) {
                                Image(systemName: type.icon).font(.title2).frame(width: 40)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.rawValue).font(.headline)
                                    Text(type.description).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Select Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
            }
        }
    }
}
