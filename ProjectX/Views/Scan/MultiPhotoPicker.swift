import SwiftUI
import PhotosUI

struct MultiPhotoPicker: UIViewControllerRepresentable {
    let maxSelection: Int
    let onImagesPicked: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = maxSelection
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagesPicked: onImagesPicked, onCancel: onCancel)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImagesPicked: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onImagesPicked: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onImagesPicked = onImagesPicked
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else { onCancel(); return }
            Task {
                var images: [UIImage] = []
                for result in results {
                    if let image = await loadImage(from: result) { images.append(image) }
                }
                await MainActor.run { images.isEmpty ? onCancel() : onImagesPicked(images) }
            }
        }

        private func loadImage(from result: PHPickerResult) async -> UIImage? {
            await withCheckedContinuation { continuation in
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                    continuation.resume(returning: object as? UIImage)
                }
            }
        }
    }
}
