import Foundation

/// Namespaced helpers for mapping extracted receipt data to app model items
enum ItemMapper {

    /// Extract the food name from an ExtractedNutrition, falling back to "Scanned Food"
    static func extractedFoodName(from nutrition: ExtractedNutrition) -> String {
        if let name = nutrition.foodName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        return "Scanned Food"
    }

    /// Find the best matching food for an item name using local string matching
    static func findMatchingFood(for itemName: String, in foods: [Food]) -> Food? {
        let nameLower = itemName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nameLower.isEmpty else { return nil }

        // Exact match
        if let food = foods.first(where: { $0.name.lowercased() == nameLower }) {
            return food
        }

        // Best substring match with length-ratio threshold
        var bestMatch: (food: Food, score: Double)?
        for food in foods {
            let foodLower = food.name.lowercased()
            if nameLower.contains(foodLower) || foodLower.contains(nameLower) {
                let shorter = Double(min(nameLower.count, foodLower.count))
                let longer = Double(max(nameLower.count, foodLower.count))
                let score = shorter / longer
                if score > (bestMatch?.score ?? 0) {
                    bestMatch = (food, score)
                }
            }
        }

        return bestMatch?.score ?? 0 >= 0.6 ? bestMatch?.food : nil
    }

    /// Map extracted receipt items to PurchasedItems, auto-linking foods by name
    static func mapToTripItems(_ extracted: [ExtractedReceiptItem], foods: [Food]) -> [PurchasedItem] {
        extracted.map { item in
            let linkedFood = findMatchingFood(for: item.name, in: foods)
            return PurchasedItem(name: item.name, quantity: item.quantityGrams, price: item.price, food: linkedFood)
        }
    }

    /// Map extracted receipt items to MealItems, auto-linking foods by name
    static func mapToMealItems(_ extracted: [ExtractedReceiptItem], foods: [Food]) -> [MealItem] {
        extracted.map { item in
            let linkedFood = findMatchingFood(for: item.name, in: foods)
            return MealItem(name: item.name, quantity: item.quantityGrams, food: linkedFood)
        }
    }

    /// Use AI to suggest category and estimate nutrition for a food name
    static func prepareFoodData(from text: String, service: LLMService) async throws -> (String, FoodCategory, NutritionInfo?) {
        let foodName = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let suggestion = try await service.suggestCategoryAndTags(for: foodName, availableTags: [])
        let nutrition = try await service.estimateNutrition(for: foodName, category: suggestion.category)

        var category = FoodCategory.other
        if let main = FoodMainCategory(rawValue: suggestion.category) {
            let sub = suggestion.subcategory.flatMap { s in main.subcategories.first { $0.rawValue == s } }
            category = FoodCategory(main: main, sub: sub)
        }

        let nutritionInfo = NutritionInfo(from: nutrition, source: .aiEstimate)
        return (foodName, category, nutritionInfo)
    }
}
