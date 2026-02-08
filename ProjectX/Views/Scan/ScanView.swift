import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ScanView: View {
    var settings: AppSettings
    var initialMode: ScanType? = nil
    var onDismiss: (() -> Void)? = nil
    @Environment(\.scanFlowManager) private var flowManager
    @Environment(\.dismiss) private var dismiss

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showTextInput = false
    @State private var receiptText = ""
    @State private var pendingOCRText: String?
    @State private var pendingImage: UIImage?
    @State private var isProcessing = false
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
                if isProcessing { processingOverlay }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { onDismiss?() ?? dismiss() } label: {
                        Image(systemName: "xmark").fontWeight(.medium)
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView(sourceType: .camera, onImageCaptured: handleImageCaptured, onCancel: { showCamera = false }).ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                CameraView(sourceType: .photoLibrary, onImageCaptured: handleImageCaptured, onCancel: { showPhotoPicker = false })
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker(allowedTypes: [.pdf, .image]) { url in showDocumentPicker = false; handleDocumentPicked(url) }
            }
            .sheet(isPresented: $showTextInput) {
                TextInputSheet(text: $receiptText, title: "Enter Text", placeholder: "Paste or type your receipt/label text below",
                    example: "Example:\nApples 1kg 2.99\nMilk 1L 1.49\nBread 500g 2.29", buttonTitle: "Continue") {
                    showTextInput = false
                    guard !receiptText.isEmpty else { return }
                    pendingOCRText = receiptText
                    if let mode = initialMode {
                        if mode == .receipt { flowManager.startReceiptReview(text: receiptText, settings: settings) }
                        else { flowManager.startNutritionReview(text: receiptText) }
                    } else {
                        flowManager.showScanTypeSelection = true
                    }
                }
            }
            .sheet(isPresented: Binding(get: { flowManager.showScanTypeSelection }, set: { flowManager.showScanTypeSelection = $0 })) {
                ScanTypeSelectionSheet(
                    onSelect: { type in
                        flowManager.showScanTypeSelection = false
                        if let image = pendingImage {
                            if type == .receipt { flowManager.startReceiptReview(image: image, settings: settings) }
                            else { flowManager.startNutritionReview(image: image) }
                        } else if let text = pendingOCRText {
                            if type == .receipt { flowManager.startReceiptReview(text: text, settings: settings) }
                            else { flowManager.startNutritionReview(text: text) }
                        }
                    },
                    onCancel: { flowManager.showScanTypeSelection = false; pendingOCRText = nil }
                ).presentationDetents([.medium])
            }
            .navigationDestination(isPresented: Binding(get: { flowManager.showReviewFromText }, set: { flowManager.showReviewFromText = $0 })) {
                if let vm = flowManager.activeReceiptViewModel {
                    ReceiptReviewView(viewModel: vm) { flowManager.clearReviewState() }
                }
            }
            .navigationDestination(isPresented: Binding(get: { flowManager.showNutritionFromText }, set: { flowManager.showNutritionFromText = $0 })) {
                if let image = flowManager.getPendingImage() {
                    NutritionLabelResultView(image: image, settings: settings)
                } else if let text = flowManager.activeNutritionText {
                    NutritionLabelResultView(text: text, settings: settings)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) { Button("OK") { errorMessage = nil } } message: { Text(errorMessage ?? "") }
        }
    }

    private var configurationRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill").font(.system(size: 60)).foregroundStyle(Color.themeWarning)
            Text("API Key Required").font(.title2).fontWeight(.semibold)
            Text("Please configure your API key in Settings to enable scanning.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
        }
    }

    private var scanOptionsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder").font(.system(size: 80)).foregroundStyle(Color.themePrimary)
            VStack(spacing: 8) {
                Text("Scan Receipt or Label").font(.title2).fontWeight(.semibold)
                Text("Take a photo, import a file, or enter text").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Button { showCamera = true } label: { Label("Take Photo", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.themePrimary)
                Button { showPhotoPicker = true } label: { Label("Choose from Library", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                    .tint(Color.themePrimary)
                Button { showDocumentPicker = true } label: { Label("Import PDF or Image", systemImage: "doc.badge.plus").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                    .tint(Color.themePrimary)
                Button { receiptText = ""; showTextInput = true } label: { Label("Enter Text", systemImage: "text.alignleft").frame(maxWidth: .infinity) }
                    .buttonStyle(.bordered)
                    .tint(Color.themePrimary)
            }.padding(.horizontal, 48)
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Processing...").font(.headline).foregroundStyle(.white)
            }.padding(32).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func handleImageCaptured(_ image: UIImage) {
        showCamera = false; showPhotoPicker = false
        processImage(image)
    }

    private func handleDocumentPicked(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf" {
            guard let data = try? Data(contentsOf: url), let image = extractImageFromPDF(data) else {
                errorMessage = "Failed to read PDF file"
                return
            }
            processImage(image)
        } else if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) {
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                errorMessage = "Failed to read image file"
                return
            }
            processImage(image)
        } else {
            errorMessage = "Unsupported file type"
        }
    }

    private func processImage(_ image: UIImage) {
        pendingImage = image
        if let mode = initialMode {
            if mode == .receipt { flowManager.startReceiptReview(image: image, settings: settings) }
            else { flowManager.startNutritionReview(image: image) }
        } else {
            flowManager.showScanTypeSelection = true
        }
    }

    private func extractImageFromPDF(_ data: Data) -> UIImage? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdfDoc = CGPDFDocument(provider),
              let page = pdfDoc.page(at: 1) else { return nil }

        let pageRect = page.getBoxRect(.mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        ctx.setFillColor(UIColor.white.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: scale, y: -scale)
        ctx.drawPDFPage(page)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
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
                        ScanTypeButton(type: type, onSelect: onSelect)
                    }
                }.padding(.horizontal)
                Spacer()
            }
            .navigationTitle("Select Type")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) } }
        }
    }
}

private struct ScanTypeButton: View {
    let type: ScanView.ScanType
    let onSelect: (ScanView.ScanType) -> Void

    var body: some View {
        Button { onSelect(type) } label: {
            HStack(spacing: 16) {
                Image(systemName: type.icon).font(.title2).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue).font(.headline)
                    Text(type.description).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }
            .padding()
            .frame(minHeight: 70)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.pressFeedback)
    }
}
