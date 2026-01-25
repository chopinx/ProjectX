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

    /// Maximum height before splitting image into segments (in pixels)
    private let maxSegmentHeight: CGFloat = 4000
    /// Overlap between segments to avoid splitting text lines
    private let segmentOverlap: CGFloat = 200
    /// Aspect ratio threshold to consider image as "long" (height/width)
    private let longImageThreshold: CGFloat = 3.0

    /// Extract text from a UIImage using Vision OCR
    /// Automatically handles long images by splitting into segments
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let aspectRatio = height / width

        // For long images, split into segments for better accuracy
        if aspectRatio > longImageThreshold && height > maxSegmentHeight {
            return try await extractTextFromSegments(image: image)
        }

        return try await performOCR(on: cgImage)
    }

    /// Split a long image into overlapping segments and extract text from each
    private func extractTextFromSegments(image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let effectiveSegmentHeight = maxSegmentHeight - segmentOverlap

        var segments: [String] = []
        var yOffset: CGFloat = 0

        while yOffset < height {
            let segmentHeight = min(maxSegmentHeight, height - yOffset)
            let rect = CGRect(x: 0, y: yOffset, width: width, height: segmentHeight)

            if let croppedCGImage = cgImage.cropping(to: rect) {
                let segmentText = try await performOCR(on: croppedCGImage)
                segments.append(segmentText)
            }

            yOffset += effectiveSegmentHeight
            // If remaining height is too small, include it in last segment
            if height - yOffset < segmentOverlap * 2 { break }
        }

        // Combine segments, removing duplicates at boundaries
        return deduplicateSegments(segments)
    }

    /// Perform OCR on a CGImage
    private func performOCR(on cgImage: CGImage) async throws -> String {
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

    /// Remove duplicate lines at segment boundaries
    private func deduplicateSegments(_ segments: [String]) -> String {
        guard !segments.isEmpty else { return "" }

        var result = segments[0]

        for i in 1..<segments.count {
            let currentLines = segments[i].components(separatedBy: "\n")
            let previousLines = result.components(separatedBy: "\n")

            // Find overlap - look for matching lines at boundary
            var skipLines = 0
            for j in 0..<min(10, currentLines.count) {
                let currentLine = currentLines[j].trimmingCharacters(in: .whitespaces)
                if currentLine.isEmpty { continue }

                for k in max(0, previousLines.count - 10)..<previousLines.count {
                    let prevLine = previousLines[k].trimmingCharacters(in: .whitespaces)
                    if currentLine == prevLine {
                        skipLines = j + 1
                        break
                    }
                }
                if skipLines > 0 { break }
            }

            // Append non-duplicate lines
            let newLines = Array(currentLines.dropFirst(skipLines))
            if !newLines.isEmpty {
                result += "\n" + newLines.joined(separator: "\n")
            }
        }

        return result
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
        guard PDFDocument(data: pdfData) != nil else {
            throw OCRError.pdfLoadFailed
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try pdfData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        return try await extractText(from: tempURL)
    }
}
