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
    var dayCount: Int

    static var zero: NutritionSummary {
        NutritionSummary(
            totalCalories: 0, totalProtein: 0, totalCarbohydrates: 0,
            totalFat: 0, totalSaturatedFat: 0, totalSugar: 0,
            totalFiber: 0, totalSodium: 0, dayCount: 0
        )
    }

    var dailyAverage: NutritionSummary {
        guard dayCount > 0 else { return .zero }
        let d = Double(dayCount)
        return NutritionSummary(
            totalCalories: totalCalories / d, totalProtein: totalProtein / d,
            totalCarbohydrates: totalCarbohydrates / d, totalFat: totalFat / d,
            totalSaturatedFat: totalSaturatedFat / d, totalSugar: totalSugar / d,
            totalFiber: totalFiber / d, totalSodium: totalSodium / d, dayCount: 1
        )
    }

    static func forTrips(_ trips: [GroceryTrip], in dateRange: ClosedRange<Date>? = nil, excludingTagNames: Set<String> = []) -> NutritionSummary {
        var summary = NutritionSummary.zero

        let filteredTrips = dateRange.map { range in trips.filter { range.contains($0.date) } } ?? trips

        for trip in filteredTrips {
            for item in trip.items where !item.isSkipped {
                // Skip items with excluded tags
                if !excludingTagNames.isEmpty,
                   let food = item.food,
                   food.tags.contains(where: { excludingTagNames.contains($0.name) }) {
                    continue
                }

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
