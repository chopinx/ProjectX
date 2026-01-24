import SwiftUI

/// Standalone nutrition label scanner for use from NewFoodSheet
struct NutritionLabelScanView: View {
    @Environment(\.dismiss) private var dismiss

    let onExtracted: (ExtractedNutrition) -> Void

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showTextInput = false
    @State private var capturedImage: UIImage?
    @State private var labelText = ""
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var settings = AppSettings()

    var body: some View {
        VStack(spacing: 24) {
            if isExtracting {
                ProgressView().scaleEffect(1.5)
                Text("Extracting nutrition info...")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else if let error = errorMessage {
                errorView(error)
            } else if let image = capturedImage {
                imagePreview(image)
            } else {
                captureOptionsView
            }
        }
        .padding()
        .navigationTitle("Scan Label")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                sourceType: .camera,
                onImageCaptured: handleImageCaptured,
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoPicker) {
            CameraView(
                sourceType: .photoLibrary,
                onImageCaptured: handleImageCaptured,
                onCancel: { showPhotoPicker = false }
            )
        }
        .sheet(isPresented: $showTextInput) {
            TextInputSheet(
                text: $labelText,
                title: "Enter Nutrition",
                placeholder: "Paste or type nutrition label text below",
                example: "Example:\nCalories 150kcal\nProtein 5g\nCarbohydrates 20g\nFat 6g",
                buttonTitle: "Extract"
            ) {
                showTextInput = false
                if !labelText.isEmpty {
                    Task { await extractNutritionFromText() }
                }
            }
        }
    }

    private var captureOptionsView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "text.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Scan Nutrition Label")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Take a photo, choose from library, or enter text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button { showPhotoPicker = true } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    labelText = ""
                    showTextInput = true
                } label: {
                    Label("Enter Text", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
            Text("Extraction Failed")
                .font(.title3)
                .fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Button("Try Again") {
                    capturedImage = nil
                    labelText = ""
                    errorMessage = nil
                }
                .buttonStyle(.bordered)

                if capturedImage != nil {
                    Button("Retry Extract") {
                        errorMessage = nil
                        Task { await extractNutritionFromImage() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Spacer()
        }
    }

    private func imagePreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 16) {
                Button("Retake") { capturedImage = nil }
                    .buttonStyle(.bordered)
                Button("Extract") { Task { await extractNutritionFromImage() } }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private func handleImageCaptured(_ image: UIImage) {
        showCamera = false
        showPhotoPicker = false
        capturedImage = image
    }

    private func extractNutritionFromImage() async {
        guard let image = capturedImage else { return }
        isExtracting = true
        errorMessage = nil

        // First do OCR
        let ocr = OCRService()
        do {
            let text = try await ocr.extractText(from: image)
            // Then extract nutrition from text
            guard let service = LLMServiceFactory.create(settings: settings) else {
                errorMessage = "Please configure your API key in Settings."
                isExtracting = false
                return
            }
            let nutrition = try await service.extractNutritionLabel(from: text)
            onExtracted(nutrition)
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to extract nutrition: \(error.localizedDescription)"
        }
        isExtracting = false
    }

    private func extractNutritionFromText() async {
        isExtracting = true
        errorMessage = nil

        guard let service = LLMServiceFactory.create(settings: settings) else {
            errorMessage = "Please configure your API key in Settings."
            isExtracting = false
            return
        }

        do {
            let nutrition = try await service.extractNutritionLabel(from: labelText)
            onExtracted(nutrition)
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to extract nutrition: \(error.localizedDescription)"
        }
        isExtracting = false
    }
}
