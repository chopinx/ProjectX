import SwiftUI

struct ScanView: View {
    var settings: AppSettings

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var showTextInput = false
    @State private var capturedImage: UIImage?
    @State private var receiptText = ""
    @State private var showReviewFromImage = false
    @State private var showReviewFromText = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                if !settings.isConfigured {
                    configurationRequiredView
                } else {
                    scanOptionsView
                }

                Spacer()
            }
            .navigationTitle("Scan")
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
                ReceiptTextInputView(text: $receiptText) {
                    showTextInput = false
                    if !receiptText.isEmpty {
                        showReviewFromText = true
                    }
                }
            }
            .navigationDestination(isPresented: $showReviewFromImage) {
                if let image = capturedImage {
                    ReceiptReviewView(image: image, settings: settings)
                }
            }
            .navigationDestination(isPresented: $showReviewFromText) {
                ReceiptReviewView(text: receiptText, settings: settings)
            }
        }
    }

    private var configurationRequiredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("API Key Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Please configure your API key in Settings to enable receipt scanning.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var scanOptionsView: some View {
        VStack(spacing: 24) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            VStack(spacing: 8) {
                Text("Scan Receipt")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Take a photo, choose from library, or enter text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    receiptText = ""
                    showTextInput = true
                } label: {
                    Label("Enter Text", systemImage: "text.alignleft")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 48)
        }
    }

    private func handleImageCaptured(_ image: UIImage) {
        showCamera = false
        showPhotoPicker = false
        capturedImage = image
        showReviewFromImage = true
    }
}

struct ReceiptTextInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Paste or type your receipt text below")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 200)

                Text("Example:\nApples 1kg 2.99\nMilk 1L 1.49\nBread 500g 2.29")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle("Enter Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Extract") {
                        onSubmit()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
