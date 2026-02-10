import SwiftUI

struct ReceiptItemRow: View {
    let item: ExtractedReceiptItem
    let linked: Food?
    let suggested: SuggestedMatch?
    let onEdit: () -> Void, onMatch: () -> Void, onConfirm: () -> Void, onDismiss: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.headline).foregroundStyle(.primary)
                        HStack(spacing: 8) { Text("\(Int(item.quantityGrams))g").font(.caption).foregroundStyle(.secondary); CapsuleBadge(text: item.category) }
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Text(String(format: "%.2f", item.price)).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }

                if let f = linked {
                    Badge(icon: "checkmark.circle.fill", text: f.name, color: Color.themeSuccess)
                } else if let s = suggested {
                    HStack(spacing: 8) {
                        Badge(icon: "sparkles", text: "\(s.food.name) (\(Int(s.confidence * 100))%)", color: Color.themeWarning)
                        Button(action: onConfirm) { Image(systemName: "checkmark").font(.caption.bold()) }.buttonStyle(.bordered).controlSize(.small).tint(Color.themeSuccess)
                        Button(action: onDismiss) { Image(systemName: "xmark").font(.caption.bold()) }.buttonStyle(.bordered).controlSize(.small).tint(.secondary)
                    }
                } else {
                    Badge(icon: "link.badge.plus", text: "Not linked", color: .secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onEdit) { Label("Edit", systemImage: "pencil") }
            Button(action: onMatch) { Label(linked == nil ? "Link to Food" : "Change Food", systemImage: "fork.knife") }
        }
    }

    private func Badge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) { Image(systemName: icon).font(.caption2); Text(text).font(.caption) }
            .foregroundStyle(color).padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.12)).clipShape(Capsule())
    }
}
