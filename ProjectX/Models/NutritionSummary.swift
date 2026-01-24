import Foundation

struct NutritionSummary {
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbohydrates: Double
    var totalFat: Double
    var totalSaturatedFat: Double
    var totalSugar: Double
    var totalFiber: Double
    var totalSodium: Double

    static var zero: NutritionSummary {
        NutritionSummary(
            totalCalories: 0, totalProtein: 0, totalCarbohydrates: 0,
            totalFat: 0, totalSaturatedFat: 0, totalSugar: 0,
            totalFiber: 0, totalSodium: 0
        )
    }

    static func forTrips(_ trips: [GroceryTrip]) -> NutritionSummary {
        var summary = NutritionSummary.zero

        for trip in trips {
            for item in trip.items where !item.isSkipped {
                guard let nutrition = item.calculatedNutrition else { continue }
                summary.totalCalories += nutrition.calories
                summary.totalProtein += nutrition.protein
                summary.totalCarbohydrates += nutrition.carbohydrates
                summary.totalFat += nutrition.fat
                summary.totalSaturatedFat += nutrition.saturatedFat
                summary.totalSugar += nutrition.sugar
                summary.totalFiber += nutrition.fiber
                summary.totalSodium += nutrition.sodium
            }
        }

        return summary
    }
}
