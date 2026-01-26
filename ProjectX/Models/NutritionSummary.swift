import Foundation

struct NutritionSummary {
    // Macronutrients
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbohydrates: Double
    var totalFat: Double
    var totalSaturatedFat: Double
    var totalOmega3: Double
    var totalOmega6: Double
    var totalSugar: Double
    var totalFiber: Double
    var totalSodium: Double
    // Micronutrients
    var totalVitaminA: Double
    var totalVitaminC: Double
    var totalVitaminD: Double
    var totalCalcium: Double
    var totalIron: Double
    var totalPotassium: Double
    var dayCount: Int

    static var zero: NutritionSummary {
        NutritionSummary(
            totalCalories: 0, totalProtein: 0, totalCarbohydrates: 0,
            totalFat: 0, totalSaturatedFat: 0, totalOmega3: 0, totalOmega6: 0,
            totalSugar: 0, totalFiber: 0, totalSodium: 0,
            totalVitaminA: 0, totalVitaminC: 0, totalVitaminD: 0,
            totalCalcium: 0, totalIron: 0, totalPotassium: 0, dayCount: 0
        )
    }

    var dailyAverage: NutritionSummary {
        guard dayCount > 0 else { return .zero }
        let d = Double(dayCount)
        return NutritionSummary(
            totalCalories: totalCalories / d, totalProtein: totalProtein / d,
            totalCarbohydrates: totalCarbohydrates / d, totalFat: totalFat / d,
            totalSaturatedFat: totalSaturatedFat / d, totalOmega3: totalOmega3 / d,
            totalOmega6: totalOmega6 / d, totalSugar: totalSugar / d,
            totalFiber: totalFiber / d, totalSodium: totalSodium / d,
            totalVitaminA: totalVitaminA / d, totalVitaminC: totalVitaminC / d,
            totalVitaminD: totalVitaminD / d, totalCalcium: totalCalcium / d,
            totalIron: totalIron / d, totalPotassium: totalPotassium / d, dayCount: 1
        )
    }

    static func forTrips(_ trips: [GroceryTrip], in dateRange: ClosedRange<Date>? = nil, excludePantryStaples: Bool = false) -> NutritionSummary {
        var summary = NutritionSummary.zero

        let filteredTrips = dateRange.map { range in trips.filter { range.contains($0.date) } } ?? trips

        for trip in filteredTrips {
            for item in trip.items where !item.isSkipped {
                // Skip pantry staples if requested
                if excludePantryStaples, let food = item.food, food.isPantryStaple { continue }

                guard let nutrition = item.calculatedNutrition else { continue }
                summary.totalCalories += nutrition.calories
                summary.totalProtein += nutrition.protein
                summary.totalCarbohydrates += nutrition.carbohydrates
                summary.totalFat += nutrition.fat
                summary.totalSaturatedFat += nutrition.saturatedFat
                summary.totalOmega3 += nutrition.omega3
                summary.totalOmega6 += nutrition.omega6
                summary.totalSugar += nutrition.sugar
                summary.totalFiber += nutrition.fiber
                summary.totalSodium += nutrition.sodium
                summary.totalVitaminA += nutrition.vitaminA
                summary.totalVitaminC += nutrition.vitaminC
                summary.totalVitaminD += nutrition.vitaminD
                summary.totalCalcium += nutrition.calcium
                summary.totalIron += nutrition.iron
                summary.totalPotassium += nutrition.potassium
            }
        }

        // Calculate day count from date range
        if let range = dateRange {
            summary.dayCount = max(1, Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1)
        } else if let first = filteredTrips.map({ $0.date }).min(),
                  let last = filteredTrips.map({ $0.date }).max() {
            summary.dayCount = max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1) + 1
        }

        return summary
    }
}
