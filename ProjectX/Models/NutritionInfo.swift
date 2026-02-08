import Foundation
import SwiftData

/// Source of nutrition data
enum NutritionSource: String, Codable, CaseIterable, Identifiable {
    case aiEstimate = "AI Estimate", labelScan = "Label Scan", manual = "Manual Entry"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .aiEstimate: "sparkles"
        case .labelScan: "camera.viewfinder"
        case .manual: "pencil"
        }
    }
}

@Model
final class NutritionInfo {
    // MARK: - Original V1 fields (non-optional)
    var calories: Double
    var protein: Double
    var carbohydrates: Double
    var fat: Double
    var saturatedFat: Double
    var sugar: Double
    var fiber: Double
    var sodium: Double

    // MARK: - V2 fields (optional for migration - nil becomes 0)
    private var sourceRaw: String?
    private var _omega3: Double?
    private var _omega6: Double?
    private var _vitaminA: Double?
    private var _vitaminC: Double?
    private var _vitaminD: Double?
    private var _calcium: Double?
    private var _iron: Double?
    private var _potassium: Double?

    // MARK: - Computed accessors for V2 fields
    var source: NutritionSource {
        get { sourceRaw.flatMap { NutritionSource(rawValue: $0) } ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
    var omega3: Double { get { _omega3 ?? 0 } set { _omega3 = newValue } }
    var omega6: Double { get { _omega6 ?? 0 } set { _omega6 = newValue } }
    var vitaminA: Double { get { _vitaminA ?? 0 } set { _vitaminA = newValue } }
    var vitaminC: Double { get { _vitaminC ?? 0 } set { _vitaminC = newValue } }
    var vitaminD: Double { get { _vitaminD ?? 0 } set { _vitaminD = newValue } }
    var calcium: Double { get { _calcium ?? 0 } set { _calcium = newValue } }
    var iron: Double { get { _iron ?? 0 } set { _iron = newValue } }
    var potassium: Double { get { _potassium ?? 0 } set { _potassium = newValue } }

    init(
        source: NutritionSource = .manual,
        calories: Double = 0, protein: Double = 0, carbohydrates: Double = 0,
        fat: Double = 0, saturatedFat: Double = 0, omega3: Double = 0, omega6: Double = 0,
        sugar: Double = 0, fiber: Double = 0, sodium: Double = 0,
        vitaminA: Double = 0, vitaminC: Double = 0, vitaminD: Double = 0,
        calcium: Double = 0, iron: Double = 0, potassium: Double = 0
    ) {
        self.sourceRaw = source.rawValue
        self.calories = calories; self.protein = protein; self.carbohydrates = carbohydrates
        self.fat = fat; self.saturatedFat = saturatedFat; self._omega3 = omega3; self._omega6 = omega6
        self.sugar = sugar; self.fiber = fiber; self.sodium = sodium
        self._vitaminA = vitaminA; self._vitaminC = vitaminC; self._vitaminD = vitaminD
        self._calcium = calcium; self._iron = iron; self._potassium = potassium
    }

    /// Scale nutrition values by weight in grams
    func scaled(byGrams grams: Double) -> NutritionInfo {
        let factor = grams / 100.0
        return NutritionInfo(
            source: source,
            calories: calories * factor,
            protein: protein * factor,
            carbohydrates: carbohydrates * factor,
            fat: fat * factor,
            saturatedFat: saturatedFat * factor,
            omega3: omega3 * factor,
            omega6: omega6 * factor,
            sugar: sugar * factor,
            fiber: fiber * factor,
            sodium: sodium * factor,
            vitaminA: vitaminA * factor,
            vitaminC: vitaminC * factor,
            vitaminD: vitaminD * factor,
            calcium: calcium * factor,
            iron: iron * factor,
            potassium: potassium * factor
        )
    }

    /// Copy values from another NutritionInfo
    func copyValues(from other: NutritionInfo) {
        source = other.source
        calories = other.calories
        protein = other.protein
        carbohydrates = other.carbohydrates
        fat = other.fat
        saturatedFat = other.saturatedFat
        omega3 = other.omega3
        omega6 = other.omega6
        sugar = other.sugar
        fiber = other.fiber
        sodium = other.sodium
        vitaminA = other.vitaminA
        vitaminC = other.vitaminC
        vitaminD = other.vitaminD
        calcium = other.calcium
        iron = other.iron
        potassium = other.potassium
    }

    /// Create from ExtractedNutrition with source
    convenience init(from extracted: ExtractedNutrition, source: NutritionSource) {
        self.init(
            source: source,
            calories: extracted.calories,
            protein: extracted.protein,
            carbohydrates: extracted.carbohydrates,
            fat: extracted.fat,
            saturatedFat: extracted.saturatedFat,
            omega3: extracted.omega3,
            omega6: extracted.omega6,
            sugar: extracted.sugar,
            fiber: extracted.fiber,
            sodium: extracted.sodium,
            vitaminA: extracted.vitaminA,
            vitaminC: extracted.vitaminC,
            vitaminD: extracted.vitaminD,
            calcium: extracted.calcium,
            iron: extracted.iron,
            potassium: extracted.potassium
        )
    }

    /// Sum multiple NutritionInfo values into one
    static func sum(_ values: [NutritionInfo?]) -> NutritionInfo {
        let nonNil = values.compactMap { $0 }
        return NutritionInfo(
            calories: nonNil.reduce(0) { $0 + $1.calories },
            protein: nonNil.reduce(0) { $0 + $1.protein },
            carbohydrates: nonNil.reduce(0) { $0 + $1.carbohydrates },
            fat: nonNil.reduce(0) { $0 + $1.fat },
            saturatedFat: nonNil.reduce(0) { $0 + $1.saturatedFat },
            omega3: nonNil.reduce(0) { $0 + $1.omega3 },
            omega6: nonNil.reduce(0) { $0 + $1.omega6 },
            sugar: nonNil.reduce(0) { $0 + $1.sugar },
            fiber: nonNil.reduce(0) { $0 + $1.fiber },
            sodium: nonNil.reduce(0) { $0 + $1.sodium },
            vitaminA: nonNil.reduce(0) { $0 + $1.vitaminA },
            vitaminC: nonNil.reduce(0) { $0 + $1.vitaminC },
            vitaminD: nonNil.reduce(0) { $0 + $1.vitaminD },
            calcium: nonNil.reduce(0) { $0 + $1.calcium },
            iron: nonNil.reduce(0) { $0 + $1.iron },
            potassium: nonNil.reduce(0) { $0 + $1.potassium }
        )
    }
}
