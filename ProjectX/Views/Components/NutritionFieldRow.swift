import SwiftUI

/// Reusable nutrition field row for forms
struct NutritionFieldRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    var isSubItem: Bool = false
    var isAIFilled: Bool = false
    var onEdit: (() -> Void)? = nil

    var body: some View {
        HStack {
            if isSubItem {
                Text("↳")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            HStack(spacing: 4) {
                Text(label)
                    .foregroundStyle(isSubItem ? .secondary : .primary)
                if isAIFilled {
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(Color.themePrimary)
                }
            }
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onChange(of: value) { _, _ in
                    onEdit?()
                }
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}
