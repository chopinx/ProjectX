import SwiftUI

struct NutritionLabelScanView: View {
    @Environment(\.dismiss) private var dismiss
    let onExtracted: (ExtractedNutrition) -> Void

    @State private var showCamera = false
    @State private var showTextInput = false
    @State private var capturedImages: [UIImage] = []
    @State private var labelText = ""
    @State private var isExtracting = false
    @State private var errorMessage: String?
    @State private var settings = AppSettings()

    var body: some View {
        VStack(spacing: 24) {
            if isExtracting {
                extractingView
            } else if let error = errorMessage {
                errorView(error)
            } else if !capturedImages.isEmpty {
                imagesPreview
            } else {
                captureOptionsView
            }
        }
        .padding()
        .navigationTitle("Scan Label")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(sourceType: .camera, onImageCaptured: { capturedImages.append($0); showCamera = false }, onCancel: { showCamera = false })
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showTextInput) {
            TextInputSheet(text: $labelText, title: "Enter Nutrition",
                          placeholder: "Paste or type nutrition label text below",
                          example: "Example:\nCalories 150kcal\nProtein 5g\nCarbohydrates 20g\nFat 6g",
                          buttonTitle: "Extract") {
                showTextInput = false
                if !labelText.isEmpty { Task { await extractFromText() } }
            }
        }
    }

    private var extractingView: some View {
        LoadingStateView(message: "Extracting nutrition info...")
    }

    private var captureOptionsView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "text.viewfinder").font(.system(size: 80)).foregroundStyle(Color.themePrimary)
            VStack(spacing: 8) {
                Text("Scan Nutrition Label").font(.title2).fontWeight(.semibold)
                Text("Take photos or enter text")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent).tint(Color.themePrimary)
                Button { labelText = ""; showTextInput = true } label: {
                    Label("Enter Text", systemImage: "text.alignleft").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).tint(Color.themePrimary)
            }.padding(.horizontal, 24)
            Spacer()
        }
    }

    private func errorView(_ message: String) -> some View {
        VStack {
            Spacer()
            ErrorStateView("Extraction Failed", message: message, retryAction: nil)
            HStack(spacing: 16) {
                Button("Try Again") { capturedImages.removeAll(); labelText = ""; errorMessage = nil }
                    .buttonStyle(.bordered).tint(Color.themePrimary)
                if !capturedImages.isEmpty {
                    Button("Retry") { errorMessage = nil; Task { await extractFromImages() } }
                        .buttonStyle(.borderedProminent).tint(Color.themePrimary)
                }
            }
            .padding(.top, 8)
            Spacer()
        }
    }

    private var imagesPreview: some View {
        VStack(spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(capturedImages.indices, id: \.self) { i in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: capturedImages[i]).resizable().scaledToFill()
                                .frame(width: 120, height: 160).clipShape(RoundedRectangle(cornerRadius: 8))
                            Button { capturedImages.remove(at: i) } label: {
                                Image(systemName: "xmark.circle.fill").font(.title3)
                                    .foregroundStyle(.white, .red)
                            }.offset(x: 6, y: -6)
                        }
                    }
                    Button { showCamera = true } label: {
                        VStack {
                            Image(systemName: "camera.fill").font(.title2)
                            Text("Add").font(.caption)
                        }
                        .frame(width: 80, height: 160)
                        .background(Color(.tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain)
                }.padding(.horizontal)
            }
            Text("\(capturedImages.count) photo\(capturedImages.count == 1 ? "" : "s") selected")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Button("Clear All") { capturedImages.removeAll() }.buttonStyle(.bordered)
                Button("Extract") { Task { await extractFromImages() } }.buttonStyle(.borderedProminent)
            }
        }
    }

    private func extractFromImages() async {
        guard let firstImage = capturedImages.first else { return }
        isExtracting = true
        errorMessage = nil
        do {
            guard let service = LLMServiceFactory.create(settings: settings) else {
                throw LLMError.invalidAPIKey
            }
            // Use first image - nutrition labels are typically complete on one photo
            onExtracted(try await service.extractNutritionLabel(from: firstImage))
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to extract: \(error.localizedDescription)"
        }
        isExtracting = false
    }

    private func extractFromText() async {
        isExtracting = true
        errorMessage = nil
        do {
            guard let service = LLMServiceFactory.create(settings: settings) else {
                throw LLMError.invalidAPIKey
            }
            onExtracted(try await service.extractNutritionLabel(from: labelText))
        } catch let error as LLMError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Failed to extract: \(error.localizedDescription)"
        }
        isExtracting = false
    }
}
