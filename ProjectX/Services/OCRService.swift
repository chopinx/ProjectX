import Foundation
import Vision
import UIKit
import PDFKit

/// Service for performing OCR on images and PDFs
final class OCRService {

    enum OCRError: LocalizedError {
        case imageConversionFailed
        case noTextFound
        case pdfLoadFailed

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed: return "Failed to process image"
            case .noTextFound: return "No text found in image"
            case .pdfLoadFailed: return "Failed to load PDF"
            }
        }
    }

    /// Extract text from a UIImage using Vision OCR
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                if text.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    continuation.resume(returning: text)
                }
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Extract text from a PDF file
    func extractText(from pdfURL: URL) async throws -> String {
        guard let document = PDFDocument(url: pdfURL) else {
            throw OCRError.pdfLoadFailed
        }

        var allText = ""

        // First try to extract text directly from PDF (for searchable PDFs)
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.string, !pageText.isEmpty {
                allText += pageText + "\n"
            }
        }

        // If no text found, try OCR on rendered pages
        if allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            for pageIndex in 0..<document.pageCount {
                if let page = document.page(at: pageIndex) {
                    let pageRect = page.bounds(for: .mediaBox)
                    let scale: CGFloat = 2.0 // Higher resolution for better OCR
                    let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

                    let renderer = UIGraphicsImageRenderer(size: size)
                    let image = renderer.image { context in
                        context.cgContext.setFillColor(UIColor.white.cgColor)
                        context.cgContext.fill(CGRect(origin: .zero, size: size))
                        context.cgContext.scaleBy(x: scale, y: scale)
                        page.draw(with: .mediaBox, to: context.cgContext)
                    }

                    let pageText = try await extractText(from: image)
                    allText += pageText + "\n"
                }
            }
        }

        if allText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw OCRError.noTextFound
        }

        return allText
    }

    /// Extract text from PDF data
    func extractText(from pdfData: Data) async throws -> String {
        guard let document = PDFDocument(data: pdfData) else {
            throw OCRError.pdfLoadFailed
        }

        // Save to temp file and use URL-based method
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try pdfData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        return try await extractText(from: tempURL)
    }
}
