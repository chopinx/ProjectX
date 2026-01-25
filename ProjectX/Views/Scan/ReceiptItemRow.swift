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
                        Text("\(Int(item.quantityGrams))g").font(.caption).foregroundStyle(.secondary)
                        CapsuleBadge(text: item.category)
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
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                        Text(food.name)
                            .font(.caption)
                    }
                    .foregroundStyle(Color.themeSuccess)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.themeSuccess.opacity(0.12))
                    .clipShape(Capsule())
                }

                Spacer()

                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil").font(.caption)
                }
                .buttonStyle(.bordered).controlSize(.small).tint(.themeInfo)

                Button(action: onMatch) {
                    Label(linkedFood == nil ? "Link" : "Change", systemImage: "fork.knife").font(.caption)
                }
                .buttonStyle(.bordered).controlSize(.small)
                .tint(linkedFood == nil ? .themePrimary : .themeSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}
