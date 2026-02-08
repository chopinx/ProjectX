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

    mutating func add(_ nutrition: NutritionInfo) {
        totalCalories += nutrition.calories
        totalProtein += nutrition.protein
        totalCarbohydrates += nutrition.carbohydrates
        totalFat += nutrition.fat
        totalSaturatedFat += nutrition.saturatedFat
        totalOmega3 += nutrition.omega3
        totalOmega6 += nutrition.omega6
        totalSugar += nutrition.sugar
        totalFiber += nutrition.fiber
        totalSodium += nutrition.sodium
        totalVitaminA += nutrition.vitaminA
        totalVitaminC += nutrition.vitaminC
        totalVitaminD += nutrition.vitaminD
        totalCalcium += nutrition.calcium
        totalIron += nutrition.iron
        totalPotassium += nutrition.potassium
    }

    private static func calculateDayCount(dates: [Date], dateRange: ClosedRange<Date>?) -> Int {
        if let range = dateRange {
            return max(1, Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1)
        } else if let first = dates.min(), let last = dates.max() {
            return max(1, Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1) + 1
        }
        return 0
    }

    static func forTrips(_ trips: [GroceryTrip], in dateRange: ClosedRange<Date>? = nil, excludePantryStaples: Bool = false) -> NutritionSummary {
        var summary = NutritionSummary.zero
        let filteredTrips = dateRange.map { range in trips.filter { range.contains($0.date) } } ?? trips

        for trip in filteredTrips {
            for item in trip.items where !item.isSkipped {
                if excludePantryStaples, let food = item.food, food.isPantryStaple { continue }
                if let nutrition = item.calculatedNutrition { summary.add(nutrition) }
            }
        }

        summary.dayCount = calculateDayCount(dates: filteredTrips.map(\.date), dateRange: dateRange)
        return summary
    }

    static func forMeals(_ meals: [Meal], in dateRange: ClosedRange<Date>? = nil, excludePantryStaples: Bool = false) -> NutritionSummary {
        var summary = NutritionSummary.zero
        let filteredMeals = dateRange.map { range in meals.filter { range.contains($0.date) } } ?? meals

        for meal in filteredMeals {
            for item in meal.items where !item.isSkipped {
                if excludePantryStaples, let food = item.food, food.isPantryStaple { continue }
                if let nutrition = item.calculatedNutrition { summary.add(nutrition) }
            }
        }

        summary.dayCount = calculateDayCount(dates: filteredMeals.map(\.date), dateRange: dateRange)
        return summary
    }

    /// Combines nutrition data from trips and meals
    static func combined(trips: [GroceryTrip], meals: [Meal], in dateRange: ClosedRange<Date>? = nil, excludePantryStaples: Bool = false) -> NutritionSummary {
        let tripSummary = forTrips(trips, in: dateRange, excludePantryStaples: excludePantryStaples)
        let mealSummary = forMeals(meals, in: dateRange, excludePantryStaples: excludePantryStaples)

        var combined = NutritionSummary(
            totalCalories: tripSummary.totalCalories + mealSummary.totalCalories,
            totalProtein: tripSummary.totalProtein + mealSummary.totalProtein,
            totalCarbohydrates: tripSummary.totalCarbohydrates + mealSummary.totalCarbohydrates,
            totalFat: tripSummary.totalFat + mealSummary.totalFat,
            totalSaturatedFat: tripSummary.totalSaturatedFat + mealSummary.totalSaturatedFat,
            totalOmega3: tripSummary.totalOmega3 + mealSummary.totalOmega3,
            totalOmega6: tripSummary.totalOmega6 + mealSummary.totalOmega6,
            totalSugar: tripSummary.totalSugar + mealSummary.totalSugar,
            totalFiber: tripSummary.totalFiber + mealSummary.totalFiber,
            totalSodium: tripSummary.totalSodium + mealSummary.totalSodium,
            totalVitaminA: tripSummary.totalVitaminA + mealSummary.totalVitaminA,
            totalVitaminC: tripSummary.totalVitaminC + mealSummary.totalVitaminC,
            totalVitaminD: tripSummary.totalVitaminD + mealSummary.totalVitaminD,
            totalCalcium: tripSummary.totalCalcium + mealSummary.totalCalcium,
            totalIron: tripSummary.totalIron + mealSummary.totalIron,
            totalPotassium: tripSummary.totalPotassium + mealSummary.totalPotassium,
            dayCount: max(tripSummary.dayCount, mealSummary.dayCount)
        )

        // Recalculate day count if using date range
        if let range = dateRange {
            combined.dayCount = max(1, Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1)
        }

        return combined
    }
}
