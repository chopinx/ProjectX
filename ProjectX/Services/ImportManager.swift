import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Manages importing content from various sources
@Observable
final class ImportManager {
    enum ImportType: String, CaseIterable, Identifiable {
        case receipt = "Receipt"
        case nutritionLabel = "Nutrition Label"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .receipt: return "doc.text.viewfinder"
            case .nutritionLabel: return "chart.bar.doc.horizontal"
            }
        }

        var description: String {
            switch self {
            case .receipt: return "Extract grocery items and prices"
            case .nutritionLabel: return "Extract nutrition information"
            }
        }
    }

    enum ImportSource {
        case image(UIImage)
        case pdf(Data)
        case text(String)
    }

    /// Pending import that needs user selection
    var pendingImport: ImportSource?

    /// Whether to show the import type selection sheet
    var showingImportTypeSelection = false

    /// Extract text from an image using OCR
    func extractText(from image: UIImage) async throws -> String {
        let ocr = OCRService()
        return try await ocr.extractText(from: image)
    }

    /// Extract text from PDF data using OCR
    func extractText(from pdfData: Data) async throws -> String {
        let ocr = OCRService()
        return try await ocr.extractText(from: pdfData)
    }

    /// Process imported content - always performs OCR first
    func processImport(_ source: ImportSource) async throws -> String {
        switch source {
        case .image(let image):
            return try await extractText(from: image)
        case .pdf(let data):
            return try await extractText(from: data)
        case .text(let text):
            return text
        }
    }

    /// Handle shared content from other apps
    func handleSharedContent(url: URL) {
        let fileExtension = url.pathExtension.lowercased()

        if fileExtension == "pdf" {
            if let data = try? Data(contentsOf: url) {
                pendingImport = .pdf(data)
                showingImportTypeSelection = true
            }
        } else if ["jpg", "jpeg", "png", "heic", "heif"].contains(fileExtension) {
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                pendingImport = .image(image)
                showingImportTypeSelection = true
            }
        }
    }

    /// Handle shared image directly
    func handleSharedImage(_ image: UIImage) {
        pendingImport = .image(image)
        showingImportTypeSelection = true
    }

    /// Handle shared PDF data
    func handleSharedPDF(_ data: Data) {
        pendingImport = .pdf(data)
        showingImportTypeSelection = true
    }
}

/// File picker for importing documents
struct DocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            // Start accessing security-scoped resource
            _ = url.startAccessingSecurityScopedResource()
            onPick(url)
            url.stopAccessingSecurityScopedResource()
        }
    }
}
