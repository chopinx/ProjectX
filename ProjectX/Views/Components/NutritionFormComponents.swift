import SwiftUI

// MARK: - Nutrition Fields

/// Consolidated nutrition field values for form editing
struct NutritionFields {
    var source: NutritionSource = .manual
    // Macronutrients
    var calories = ""
    var protein = ""
    var carbohydrates = ""
    var fat = ""
    var saturatedFat = ""
    var omega3 = ""
    var omega6 = ""
    var sugar = ""
    var fiber = ""
    var sodium = ""
    // Micronutrients
    var vitaminA = ""
    var vitaminC = ""
    var vitaminD = ""
    var calcium = ""
    var iron = ""
    var potassium = ""
    // Track which fields were filled by AI
    var aiFilledFields: Set<String> = []

    var hasValues: Bool { !calories.isEmpty }

    init() {}

    init(from nutrition: NutritionInfo?) {
        guard let n = nutrition else { return }
        source = n.source
        calories = n.calories > 0 ? String(format: "%.1f", n.calories) : ""
        protein = n.protein > 0 ? String(format: "%.1f", n.protein) : ""
        carbohydrates = n.carbohydrates > 0 ? String(format: "%.1f", n.carbohydrates) : ""
        fat = n.fat > 0 ? String(format: "%.1f", n.fat) : ""
        saturatedFat = n.saturatedFat > 0 ? String(format: "%.1f", n.saturatedFat) : ""
        omega3 = n.omega3 > 0 ? String(format: "%.1f", n.omega3) : ""
        omega6 = n.omega6 > 0 ? String(format: "%.1f", n.omega6) : ""
        sugar = n.sugar > 0 ? String(format: "%.1f", n.sugar) : ""
        fiber = n.fiber > 0 ? String(format: "%.1f", n.fiber) : ""
        sodium = n.sodium > 0 ? String(format: "%.1f", n.sodium) : ""
        vitaminA = n.vitaminA > 0 ? String(format: "%.1f", n.vitaminA) : ""
        vitaminC = n.vitaminC > 0 ? String(format: "%.1f", n.vitaminC) : ""
        vitaminD = n.vitaminD > 0 ? String(format: "%.1f", n.vitaminD) : ""
        calcium = n.calcium > 0 ? String(format: "%.1f", n.calcium) : ""
        iron = n.iron > 0 ? String(format: "%.1f", n.iron) : ""
        potassium = n.potassium > 0 ? String(format: "%.1f", n.potassium) : ""
    }

    /// Check if a field is empty or zero
    private func isEmpty(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || (Double(trimmed) ?? 0) == 0
    }

    /// Populate all fields (replaces existing values)
    mutating func populate(from nutrition: ExtractedNutrition, source newSource: NutritionSource) {
        source = newSource
        aiFilledFields.removeAll()
        calories = String(format: "%.1f", nutrition.calories)
        protein = String(format: "%.1f", nutrition.protein)
        carbohydrates = String(format: "%.1f", nutrition.carbohydrates)
        fat = String(format: "%.1f", nutrition.fat)
        saturatedFat = String(format: "%.1f", nutrition.saturatedFat)
        omega3 = String(format: "%.1f", nutrition.omega3)
        omega6 = String(format: "%.1f", nutrition.omega6)
        sugar = String(format: "%.1f", nutrition.sugar)
        fiber = String(format: "%.1f", nutrition.fiber)
        sodium = String(format: "%.1f", nutrition.sodium)
        vitaminA = String(format: "%.1f", nutrition.vitaminA)
        vitaminC = String(format: "%.1f", nutrition.vitaminC)
        vitaminD = String(format: "%.1f", nutrition.vitaminD)
        calcium = String(format: "%.1f", nutrition.calcium)
        iron = String(format: "%.1f", nutrition.iron)
        potassium = String(format: "%.1f", nutrition.potassium)
    }

    /// Populate only empty/zero fields, keeping existing values
    mutating func populateEmptyOnly(from n: ExtractedNutrition, source newSource: NutritionSource) {
        var filled: Set<String> = []

        if isEmpty(calories) && n.calories > 0 { calories = String(format: "%.1f", n.calories); filled.insert("calories") }
        if isEmpty(protein) && n.protein > 0 { protein = String(format: "%.1f", n.protein); filled.insert("protein") }
        if isEmpty(carbohydrates) && n.carbohydrates > 0 { carbohydrates = String(format: "%.1f", n.carbohydrates); filled.insert("carbohydrates") }
        if isEmpty(fat) && n.fat > 0 { fat = String(format: "%.1f", n.fat); filled.insert("fat") }
        if isEmpty(saturatedFat) && n.saturatedFat > 0 { saturatedFat = String(format: "%.1f", n.saturatedFat); filled.insert("saturatedFat") }
        if isEmpty(omega3) && n.omega3 > 0 { omega3 = String(format: "%.1f", n.omega3); filled.insert("omega3") }
        if isEmpty(omega6) && n.omega6 > 0 { omega6 = String(format: "%.1f", n.omega6); filled.insert("omega6") }
        if isEmpty(sugar) && n.sugar > 0 { sugar = String(format: "%.1f", n.sugar); filled.insert("sugar") }
        if isEmpty(fiber) && n.fiber > 0 { fiber = String(format: "%.1f", n.fiber); filled.insert("fiber") }
        if isEmpty(sodium) && n.sodium > 0 { sodium = String(format: "%.1f", n.sodium); filled.insert("sodium") }
        if isEmpty(vitaminA) && n.vitaminA > 0 { vitaminA = String(format: "%.1f", n.vitaminA); filled.insert("vitaminA") }
        if isEmpty(vitaminC) && n.vitaminC > 0 { vitaminC = String(format: "%.1f", n.vitaminC); filled.insert("vitaminC") }
        if isEmpty(vitaminD) && n.vitaminD > 0 { vitaminD = String(format: "%.1f", n.vitaminD); filled.insert("vitaminD") }
        if isEmpty(calcium) && n.calcium > 0 { calcium = String(format: "%.1f", n.calcium); filled.insert("calcium") }
        if isEmpty(iron) && n.iron > 0 { iron = String(format: "%.1f", n.iron); filled.insert("iron") }
        if isEmpty(potassium) && n.potassium > 0 { potassium = String(format: "%.1f", n.potassium); filled.insert("potassium") }

        if !filled.isEmpty { source = newSource; aiFilledFields = filled }
    }

    /// Clear AI filled status for a specific field (when user edits it)
    mutating func clearAIFilled(_ key: String) {
        aiFilledFields.remove(key)
    }

    /// Get existing non-empty values as dictionary for LLM context
    func toExistingValuesDictionary() -> [String: Double] {
        let fields: [(String, String)] = [
            ("calories", calories), ("protein", protein), ("carbohydrates", carbohydrates),
            ("fat", fat), ("saturatedFat", saturatedFat), ("omega3", omega3), ("omega6", omega6),
            ("sugar", sugar), ("fiber", fiber), ("sodium", sodium),
            ("vitaminA", vitaminA), ("vitaminC", vitaminC), ("vitaminD", vitaminD),
            ("calcium", calcium), ("iron", iron), ("potassium", potassium)
        ]
        var dict: [String: Double] = [:]
        for (key, value) in fields {
            if let v = Double(value), v > 0 { dict[key] = v }
        }
        return dict
    }

    func toNutritionInfo() -> NutritionInfo {
        NutritionInfo(
            source: source,
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbohydrates: Double(carbohydrates) ?? 0,
            fat: Double(fat) ?? 0,
            saturatedFat: Double(saturatedFat) ?? 0,
            omega3: Double(omega3) ?? 0,
            omega6: Double(omega6) ?? 0,
            sugar: Double(sugar) ?? 0,
            fiber: Double(fiber) ?? 0,
            sodium: Double(sodium) ?? 0,
            vitaminA: Double(vitaminA) ?? 0,
            vitaminC: Double(vitaminC) ?? 0,
            vitaminD: Double(vitaminD) ?? 0,
            calcium: Double(calcium) ?? 0,
            iron: Double(iron) ?? 0,
            potassium: Double(potassium) ?? 0
        )
    }
}

// MARK: - Nutrition Form Section

/// Reusable nutrition form section with hierarchical nutrition fields
struct NutritionFormSection: View {
    @Binding var fields: NutritionFields
    var showSource: Bool = true

    var body: some View {
        if showSource && fields.hasValues {
            Section {
                HStack {
                    Label(fields.source.rawValue, systemImage: fields.source.icon)
                        .font(.subheadline)
                    Spacer()
                }
                .foregroundStyle(.secondary)
            } header: { Text("Nutrition Source") }
        }
        if !fields.aiFilledFields.isEmpty {
            Section {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.themePrimary)
                    Text("Fields marked with")
                    Image(systemName: "sparkles")
                        .font(.caption2)
                        .foregroundStyle(Color.themePrimary)
                    Text("were filled by AI")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        Section("Macronutrients per 100g") {
            NutritionFieldRow(label: "Calories", value: $fields.calories, unit: "kcal",
                              isAIFilled: fields.aiFilledFields.contains("calories")) { fields.clearAIFilled("calories") }
            NutritionFieldRow(label: "Protein", value: $fields.protein, unit: "g",
                              isAIFilled: fields.aiFilledFields.contains("protein")) { fields.clearAIFilled("protein") }
            NutritionFieldRow(label: "Carbohydrates", value: $fields.carbohydrates, unit: "g",
                              isAIFilled: fields.aiFilledFields.contains("carbohydrates")) { fields.clearAIFilled("carbohydrates") }
            NutritionFieldRow(label: "Sugar", value: $fields.sugar, unit: "g", isSubItem: true,
                              isAIFilled: fields.aiFilledFields.contains("sugar")) { fields.clearAIFilled("sugar") }
            NutritionFieldRow(label: "Fiber", value: $fields.fiber, unit: "g", isSubItem: true,
                              isAIFilled: fields.aiFilledFields.contains("fiber")) { fields.clearAIFilled("fiber") }
            NutritionFieldRow(label: "Fat", value: $fields.fat, unit: "g",
                              isAIFilled: fields.aiFilledFields.contains("fat")) { fields.clearAIFilled("fat") }
            NutritionFieldRow(label: "Saturated Fat", value: $fields.saturatedFat, unit: "g", isSubItem: true,
                              isAIFilled: fields.aiFilledFields.contains("saturatedFat")) { fields.clearAIFilled("saturatedFat") }
            NutritionFieldRow(label: "Omega-3", value: $fields.omega3, unit: "g", isSubItem: true,
                              isAIFilled: fields.aiFilledFields.contains("omega3")) { fields.clearAIFilled("omega3") }
            NutritionFieldRow(label: "Omega-6", value: $fields.omega6, unit: "g", isSubItem: true,
                              isAIFilled: fields.aiFilledFields.contains("omega6")) { fields.clearAIFilled("omega6") }
            NutritionFieldRow(label: "Sodium", value: $fields.sodium, unit: "mg",
                              isAIFilled: fields.aiFilledFields.contains("sodium")) { fields.clearAIFilled("sodium") }
        }

        Section("Micronutrients per 100g") {
            NutritionFieldRow(label: "Vitamin A", value: $fields.vitaminA, unit: "mcg",
                              isAIFilled: fields.aiFilledFields.contains("vitaminA")) { fields.clearAIFilled("vitaminA") }
            NutritionFieldRow(label: "Vitamin C", value: $fields.vitaminC, unit: "mg",
                              isAIFilled: fields.aiFilledFields.contains("vitaminC")) { fields.clearAIFilled("vitaminC") }
            NutritionFieldRow(label: "Vitamin D", value: $fields.vitaminD, unit: "mcg",
                              isAIFilled: fields.aiFilledFields.contains("vitaminD")) { fields.clearAIFilled("vitaminD") }
            NutritionFieldRow(label: "Calcium", value: $fields.calcium, unit: "mg",
                              isAIFilled: fields.aiFilledFields.contains("calcium")) { fields.clearAIFilled("calcium") }
            NutritionFieldRow(label: "Iron", value: $fields.iron, unit: "mg",
                              isAIFilled: fields.aiFilledFields.contains("iron")) { fields.clearAIFilled("iron") }
            NutritionFieldRow(label: "Potassium", value: $fields.potassium, unit: "mg",
                              isAIFilled: fields.aiFilledFields.contains("potassium")) { fields.clearAIFilled("potassium") }
        }
    }
}

// MARK: - Nutrition Summary Row

/// Compact nutrition display for trip/item rows
struct NutritionSummaryRow: View {
    let nutrition: NutritionInfo
    var isCompact: Bool = false

    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            nutrientLabel("Cal", value: nutrition.calories, unit: "", color: .nutritionCalories)
            nutrientLabel("P", value: nutrition.protein, unit: "g", color: .nutritionProtein)
            nutrientLabel("C", value: nutrition.carbohydrates, unit: "g", color: .nutritionCarbs)
            nutrientLabel("F", value: nutrition.fat, unit: "g", color: .nutritionFat)
            nutrientLabel("S", value: nutrition.sugar, unit: "g", color: .nutritionSugar)
        }
        .font(isCompact ? .caption2 : .caption)
    }

    private func nutrientLabel(_ label: String, value: Double, unit: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Text(label).fontWeight(.medium).foregroundStyle(color)
            Text("\(Int(value))\(unit)").foregroundStyle(.secondary)
        }
    }
}

// MARK: - Macro Stat

/// Single macro nutrient stat display (value + unit + label)
struct MacroStat: View {
    let value: Int, unit: String, label: String, color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Text("\(value)").font(.subheadline).fontWeight(.semibold)
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
            Text(label).font(.caption2).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Nutrition Summary Card

/// Shared summary card showing item count, macros, and unlinked warning.
/// Used by both TripDetailView and MealDetailView.
struct NutritionSummaryCard: View {
    let activeItemCount: Int
    let linkedCount: Int
    let nutrition: (cal: Double, pro: Double, carb: Double, fat: Double, fiber: Double, sugar: Double)
    var icon: String = "cart.fill"
    var priceTotal: Double?

    var body: some View {
        VStack(spacing: 12) {
            // Items header (with optional price)
            if let price = priceTotal {
                HStack(spacing: 0) {
                    itemCountView.frame(maxWidth: .infinity)
                    Divider().frame(height: 36)
                    HStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle.fill").foregroundStyle(.green)
                        Text(String(format: "%.2f", price)).font(.title3).fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                itemCountView.frame(maxWidth: .infinity)
            }

            Divider()

            // Main Macros Row
            HStack(spacing: 0) {
                MacroStat(value: Int(nutrition.cal), unit: "kcal", label: "Cal", color: .nutritionCalories)
                MacroStat(value: Int(nutrition.pro), unit: "g", label: "Pro", color: .nutritionProtein)
                MacroStat(value: Int(nutrition.carb), unit: "g", label: "Carb", color: .nutritionCarbs)
                MacroStat(value: Int(nutrition.fat), unit: "g", label: "Fat", color: .nutritionFat)
            }

            // Fiber & Sugar Row
            HStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill").font(.caption).foregroundStyle(.green)
                    Text("\(Int(nutrition.fiber))g fiber").font(.caption)
                }
                .frame(maxWidth: .infinity)
                HStack(spacing: 4) {
                    Image(systemName: "cube.fill").font(.caption).foregroundStyle(.pink)
                    Text("\(Int(nutrition.sugar))g sugar").font(.caption)
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)

            // Warning for unlinked items
            if linkedCount < activeItemCount {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("\(activeItemCount - linkedCount) items not linked to food").font(.caption)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var itemCountView: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(activeItemCount)").font(.title3).fontWeight(.semibold)
                Text("\(linkedCount) linked").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
