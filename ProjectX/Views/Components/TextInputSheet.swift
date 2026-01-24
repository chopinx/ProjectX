import SwiftUI

/// Reusable text input sheet for receipt text or nutrition label text
struct TextInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let title: String
    let placeholder: String
    let example: String
    let buttonTitle: String
    let onSubmit: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.body)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(minHeight: 200)

                Text(example)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(buttonTitle) { onSubmit() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
