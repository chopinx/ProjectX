import Foundation
import SwiftData

@Model
final class NutritionInfo {
    var calories: Double      // kcal per 100g
    var protein: Double       // g per 100g
    var carbohydrates: Double // g per 100g
    var fat: Double           // g per 100g
    var saturatedFat: Double  // g per 100g
    var sugar: Double         // g per 100g
    var fiber: Double         // g per 100g
    var sodium: Double        // mg per 100g

    init(
        calories: Double = 0,
        protein: Double = 0,
        carbohydrates: Double = 0,
        fat: Double = 0,
        saturatedFat: Double = 0,
        sugar: Double = 0,
        fiber: Double = 0,
        sodium: Double = 0
    ) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.saturatedFat = saturatedFat
        self.sugar = sugar
        self.fiber = fiber
        self.sodium = sodium
    }

    /// Scale nutrition values by weight in grams
    func scaled(byGrams grams: Double) -> NutritionInfo {
        let factor = grams / 100.0
        return NutritionInfo(
            calories: calories * factor,
            protein: protein * factor,
            carbohydrates: carbohydrates * factor,
            fat: fat * factor,
            saturatedFat: saturatedFat * factor,
            sugar: sugar * factor,
            fiber: fiber * factor,
            sodium: sodium * factor
        )
    }

    /// Copy values from another NutritionInfo
    func copyValues(from other: NutritionInfo) {
        calories = other.calories
        protein = other.protein
        carbohydrates = other.carbohydrates
        fat = other.fat
        saturatedFat = other.saturatedFat
        sugar = other.sugar
        fiber = other.fiber
        sodium = other.sodium
    }

    /// Create from ExtractedNutrition
    convenience init(from extracted: ExtractedNutrition) {
        self.init(
            calories: extracted.calories,
            protein: extracted.protein,
            carbohydrates: extracted.carbohydrates,
            fat: extracted.fat,
            saturatedFat: extracted.saturatedFat,
            sugar: extracted.sugar,
            fiber: extracted.fiber,
            sodium: extracted.sodium
        )
    }
}
