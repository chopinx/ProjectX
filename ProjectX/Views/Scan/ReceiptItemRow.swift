import SwiftUI

struct ReceiptItemRow: View {
    let item: ExtractedReceiptItem
    let linkedFood: Food?
    let onEdit: () -> Void
    let onMatch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text("\(Int(item.quantityGrams))g")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.category)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                Spacer()
                Text(String(format: "%.2f", item.price))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack(spacing: 8) {
                if let food = linkedFood {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption2)
                        Text(food.name)
                            .font(.caption)
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                }

                Spacer()

                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    onMatch()
                } label: {
                    Label(linkedFood == nil ? "Link" : "Change", systemImage: "fork.knife")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}
