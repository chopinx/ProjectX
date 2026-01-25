import SwiftUI

// MARK: - Capsule Badge

/// Reusable capsule-styled badge for tags, categories, counts
struct CapsuleBadge: View {
    let text: String
    var color: Color = .secondary
    var style: Style = .filled

    enum Style { case filled, outlined }

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(style == .filled ? color.opacity(0.15) : Color.clear)
            .foregroundStyle(color)
            .overlay(style == .outlined ? Capsule().stroke(color, lineWidth: 1.5) : nil)
            .clipShape(Capsule())
    }
}

// MARK: - Loading View

struct LoadingStateView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text(message).font(.headline).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    init(_ title: String = "Error", message: String, retryAction: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(Color.themeWarning)
            Text(title).font(.title3).fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            if let retry = retryAction {
                Button("Try Again", action: retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.themePrimary)
            }
        }
    }
}

// MARK: - Delete Confirmation Modifier

struct DeleteConfirmationModifier<T>: ViewModifier {
    @Binding var item: T?
    let title: String
    let message: (T) -> String
    let onDelete: (T) -> Void

    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: .init(
                get: { item != nil },
                set: { if !$0 { item = nil } }
            )) {
                Button("Cancel", role: .cancel) { item = nil }
                Button("Delete", role: .destructive) {
                    if let toDelete = item {
                        onDelete(toDelete)
                    }
                    item = nil
                }
            } message: {
                if let toDelete = item {
                    Text(message(toDelete))
                }
            }
    }
}

extension View {
    func deleteConfirmation<T>(
        _ title: String,
        item: Binding<T?>,
        message: @escaping (T) -> String,
        onDelete: @escaping (T) -> Void
    ) -> some View {
        modifier(DeleteConfirmationModifier(item: item, title: title, message: message, onDelete: onDelete))
    }
}

// MARK: - Unit Text Field

/// Text field with trailing unit label, commonly used for quantity/price inputs
struct UnitTextField: View {
    let placeholder: String
    @Binding var value: String
    let unit: String
    var keyboard: UIKeyboardType = .decimalPad

    var body: some View {
        HStack {
            TextField(placeholder, text: $value)
                .keyboardType(keyboard)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Nutrition Fields

/// Consolidated nutrition field values for form editing
struct NutritionFields {
    var calories = ""
    var protein = ""
    var carbohydrates = ""
    var fat = ""
    var saturatedFat = ""
    var sugar = ""
    var fiber = ""
    var sodium = ""

    var hasValues: Bool { !calories.isEmpty }

    init() {}

    init(from nutrition: NutritionInfo?) {
        guard let n = nutrition else { return }
        calories = n.calories > 0 ? String(format: "%.1f", n.calories) : ""
        protein = n.protein > 0 ? String(format: "%.1f", n.protein) : ""
        carbohydrates = n.carbohydrates > 0 ? String(format: "%.1f", n.carbohydrates) : ""
        fat = n.fat > 0 ? String(format: "%.1f", n.fat) : ""
        saturatedFat = n.saturatedFat > 0 ? String(format: "%.1f", n.saturatedFat) : ""
        sugar = n.sugar > 0 ? String(format: "%.1f", n.sugar) : ""
        fiber = n.fiber > 0 ? String(format: "%.1f", n.fiber) : ""
        sodium = n.sodium > 0 ? String(format: "%.1f", n.sodium) : ""
    }

    mutating func populate(from nutrition: ExtractedNutrition) {
        calories = String(format: "%.1f", nutrition.calories)
        protein = String(format: "%.1f", nutrition.protein)
        carbohydrates = String(format: "%.1f", nutrition.carbohydrates)
        fat = String(format: "%.1f", nutrition.fat)
        saturatedFat = String(format: "%.1f", nutrition.saturatedFat)
        sugar = String(format: "%.1f", nutrition.sugar)
        fiber = String(format: "%.1f", nutrition.fiber)
        sodium = String(format: "%.1f", nutrition.sodium)
    }

    func toNutritionInfo() -> NutritionInfo {
        NutritionInfo(
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbohydrates: Double(carbohydrates) ?? 0,
            fat: Double(fat) ?? 0,
            saturatedFat: Double(saturatedFat) ?? 0,
            sugar: Double(sugar) ?? 0,
            fiber: Double(fiber) ?? 0,
            sodium: Double(sodium) ?? 0
        )
    }
}

// MARK: - Nutrition Form Section

/// Reusable nutrition form section with all 8 nutrition fields
struct NutritionFormSection: View {
    @Binding var fields: NutritionFields

    var body: some View {
        Section("Nutrition per 100g") {
            NutritionFieldRow(label: "Calories", value: $fields.calories, unit: "kcal")
            NutritionFieldRow(label: "Protein", value: $fields.protein, unit: "g")
            NutritionFieldRow(label: "Carbohydrates", value: $fields.carbohydrates, unit: "g")
            NutritionFieldRow(label: "Fat", value: $fields.fat, unit: "g")
            NutritionFieldRow(label: "Saturated Fat", value: $fields.saturatedFat, unit: "g")
            NutritionFieldRow(label: "Sugar", value: $fields.sugar, unit: "g")
            NutritionFieldRow(label: "Fiber", value: $fields.fiber, unit: "g")
            NutritionFieldRow(label: "Sodium", value: $fields.sodium, unit: "mg")
        }
    }
}
