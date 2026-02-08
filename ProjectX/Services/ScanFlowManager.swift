import SwiftUI
import UIKit

/// Manages scan flow state to persist across app backgrounding
@Observable
final class ScanFlowManager {
    // Navigation state
    var showReviewFromText = false
    var showNutritionFromText = false
    var showScanTypeSelection = false
    var requestScanTab = false  // Request to open Scan tab

    // Pending data - stored as base64 for images to survive app backgrounding
    var pendingOCRText: String?
    var pendingImageData: Data?
    var pendingPDFData: Data?
    private var pendingImageTimestamp: Date?
    private let imageExpirationInterval: TimeInterval = 300 // 5 minutes

    // Active view model to preserve edit state
    var activeReceiptViewModel: ReceiptReviewViewModel?
    var activeNutritionText: String?

    func setPendingImage(_ image: UIImage) {
        pendingImageData = image.jpegData(compressionQuality: 0.8)
        pendingImageTimestamp = Date()
    }

    func getPendingImage() -> UIImage? {
        cleanupExpiredImageIfNeeded()
        guard let data = pendingImageData else { return nil }
        return UIImage(data: data)
    }

    /// Clears pending image data if it's older than the expiration interval
    func cleanupExpiredImageIfNeeded() {
        guard let timestamp = pendingImageTimestamp else { return }
        if Date().timeIntervalSince(timestamp) > imageExpirationInterval {
            pendingImageData = nil
            pendingImageTimestamp = nil
        }
    }

    func startReceiptReview(text: String, settings: AppSettings) {
        pendingOCRText = text
        activeReceiptViewModel = ReceiptReviewViewModel(source: .text(text), settings: settings)
        showReviewFromText = true
    }

    func startReceiptReview(image: UIImage, settings: AppSettings) {
        setPendingImage(image)
        activeReceiptViewModel = ReceiptReviewViewModel(source: .image(image), settings: settings)
        showReviewFromText = true
    }

    func startNutritionReview(text: String) {
        activeNutritionText = text
        showNutritionFromText = true
    }

    func startNutritionReview(image: UIImage) {
        setPendingImage(image)
        showNutritionFromText = true
    }

    func startReceiptReview(pdfData: Data, settings: AppSettings) {
        pendingPDFData = pdfData
        activeReceiptViewModel = ReceiptReviewViewModel(source: .pdf(pdfData), settings: settings)
        showReviewFromText = true
    }

    func startNutritionReview(pdfData: Data) {
        pendingPDFData = pdfData
        showNutritionFromText = true
    }

    func clearReviewState() {
        showReviewFromText = false
        showNutritionFromText = false
        pendingOCRText = nil
        pendingImageData = nil
        pendingPDFData = nil
        pendingImageTimestamp = nil
        activeReceiptViewModel = nil
        activeNutritionText = nil
    }

    func clearSelectionState() {
        showScanTypeSelection = false
    }

    func requestScanForReceipt() {
        requestScanTab = true
    }
}

// MARK: - Environment Key

private struct ScanFlowManagerKey: EnvironmentKey {
    static let defaultValue = ScanFlowManager()
}

extension EnvironmentValues {
    var scanFlowManager: ScanFlowManager {
        get { self[ScanFlowManagerKey.self] }
        set { self[ScanFlowManagerKey.self] = newValue }
    }
}
