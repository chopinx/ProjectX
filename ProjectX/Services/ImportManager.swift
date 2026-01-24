import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Manages importing content from various sources
@Observable
final class ImportManager {
    enum ImportSource {
        case image(UIImage)
        case pdf(Data)
        case text(String)
    }

    var pendingImport: ImportSource?
    var showingImportTypeSelection = false

    func extractText(from image: UIImage) async throws -> String {
        try await OCRService().extractText(from: image)
    }

    func extractText(from pdfData: Data) async throws -> String {
        try await OCRService().extractText(from: pdfData)
    }

    func processImport(_ source: ImportSource) async throws -> String {
        switch source {
        case .image(let image): return try await extractText(from: image)
        case .pdf(let data): return try await extractText(from: data)
        case .text(let text): return text
        }
    }

    func handleSharedContent(url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "pdf", let data = try? Data(contentsOf: url) {
            pendingImport = .pdf(data)
            showingImportTypeSelection = true
        } else if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext),
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) {
            pendingImport = .image(image)
            showingImportTypeSelection = true
        }
    }

    func handleSharedImage(_ image: UIImage) {
        pendingImport = .image(image)
        showingImportTypeSelection = true
    }

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

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            onPick(url)
            url.stopAccessingSecurityScopedResource()
        }
    }
}
