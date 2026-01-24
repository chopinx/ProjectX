import Foundation
import SwiftData

@Model
final class PurchasedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double  // Always in grams - LLM converts all units
    var price: Double
    var food: Food?
    var trip: GroceryTrip?
    var isSkipped: Bool

    /// Calculate nutrition for this item based on quantity (in grams)
    var calculatedNutrition: NutritionInfo? {
        food?.nutrition?.scaled(byGrams: quantity)
    }

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 100,  // Default 100g
        price: Double = 0,
        food: Food? = nil,
        isSkipped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
        self.food = food
        self.isSkipped = isSkipped
    }
}
