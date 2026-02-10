import UIKit
import Vision

/// Extracts text from images using the Vision framework
enum OCRService {

    /// Extract text from a UIImage, handling long images by segmenting with overlap
    static func extractText(from image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        let imageHeight = CGFloat(cgImage.height)
        let imageWidth = CGFloat(cgImage.width)
        let aspectRatio = imageHeight / max(imageWidth, 1)

        // For tall images (receipts), segment with overlap to avoid missing text at boundaries
        if aspectRatio > 3.0 && imageHeight > maxSegmentHeight {
            return await extractTextFromSegments(cgImage: cgImage)
        }

        return recognizeText(in: cgImage)
    }

    /// Extract text from PDF data by rendering the first page as an image
    static func extractText(fromPDF data: Data) async -> String? {
        guard let image = PDFHelper.extractImage(from: data) else { return nil }
        return await extractText(from: image)
    }

    /// Augment an LLM prompt with OCR-extracted text from an image.
    /// Returns the original prompt unchanged if OCR extraction fails or yields no text.
    static func augmentPrompt(_ prompt: String, withImage image: UIImage) async -> String {
        guard let ocrText = await extractText(from: image), !ocrText.isEmpty else {
            return prompt
        }
        return prompt + "\n\nOCR extracted text from image:\n\(ocrText)"
    }

    /// Augment an LLM prompt with OCR-extracted text from PDF data.
    /// Returns the original prompt unchanged if OCR extraction fails or yields no text.
    static func augmentPrompt(_ prompt: String, withPDF data: Data) async -> String {
        guard let ocrText = await extractText(fromPDF: data), !ocrText.isEmpty else {
            return prompt
        }
        return prompt + "\n\nOCR extracted text from document:\n\(ocrText)"
    }

    // MARK: - Private

    private static let maxSegmentHeight: CGFloat = 4000
    private static let segmentOverlap: CGFloat = 200

    private static func extractTextFromSegments(cgImage: CGImage) async -> String? {
        let imageHeight = CGFloat(cgImage.height)
        let imageWidth = CGFloat(cgImage.width)
        var allTexts: [String] = []
        var y: CGFloat = 0

        while y < imageHeight {
            let segmentHeight = min(maxSegmentHeight, imageHeight - y)
            let rect = CGRect(x: 0, y: y, width: imageWidth, height: segmentHeight)

            guard let cropped = cgImage.cropping(to: rect) else {
                y += maxSegmentHeight - segmentOverlap
                continue
            }

            if let text = recognizeText(in: cropped), !text.isEmpty {
                // For overlapping segments, skip lines that duplicate the previous segment's tail
                if !allTexts.isEmpty && y > 0 {
                    let lines = text.components(separatedBy: "\n")
                    let prevLines = allTexts.last?.components(separatedBy: "\n") ?? []
                    let overlapLines = findOverlapCount(prevTail: prevLines, currentHead: lines)
                    let deduped = lines.dropFirst(overlapLines).joined(separator: "\n")
                    if !deduped.isEmpty { allTexts.append(deduped) }
                } else {
                    allTexts.append(text)
                }
            }

            y += maxSegmentHeight - segmentOverlap
        }

        let result = allTexts.joined(separator: "\n")
        return result.isEmpty ? nil : result
    }

    private static func findOverlapCount(prevTail: [String], currentHead: [String]) -> Int {
        // Look for matching lines in the overlap region
        let tailCount = min(10, prevTail.count)
        let headCount = min(10, currentHead.count)
        guard tailCount > 0, headCount > 0 else { return 0 }

        let tail = prevTail.suffix(tailCount)
        for overlapSize in (1...headCount).reversed() {
            let headSlice = currentHead.prefix(overlapSize)
            let tailSlice = tail.suffix(overlapSize)
            if Array(tailSlice) == Array(headSlice) { return overlapSize }
        }
        return 0
    }

    private static func recognizeText(in cgImage: CGImage) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observations = request.results else { return nil }

        let text = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")

        return text.isEmpty ? nil : text
    }
}
