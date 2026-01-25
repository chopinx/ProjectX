import SwiftUI

/// Reusable nutrition field row for forms
struct NutritionFieldRow: View {
    let label: String
    @Binding var value: String
    let unit: String
    var isSubItem: Bool = false

    var body: some View {
        HStack {
            if isSubItem {
                Text("↳")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            Text(label)
                .foregroundStyle(isSubItem ? .secondary : .primary)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}
