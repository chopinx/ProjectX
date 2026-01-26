import Foundation
import SwiftData

@Model
final class GroceryTrip {
    @Attribute(.unique) var id: UUID
    var date: Date
    var storeName: String?
    @Relationship(deleteRule: .cascade, inverse: \PurchasedItem.trip) var items: [PurchasedItem]
    var createdAt: Date
    var updatedAt: Date

    var totalSpent: Double {
        items.reduce(0) { $0 + $1.price }
    }

    /// Total nutrition for all non-skipped items with linked foods
    var totalNutrition: NutritionInfo {
        let validItems = items.filter { !$0.isSkipped }
        return NutritionInfo(
            calories: validItems.compactMap { $0.calculatedNutrition?.calories }.reduce(0, +),
            protein: validItems.compactMap { $0.calculatedNutrition?.protein }.reduce(0, +),
            carbohydrates: validItems.compactMap { $0.calculatedNutrition?.carbohydrates }.reduce(0, +),
            fat: validItems.compactMap { $0.calculatedNutrition?.fat }.reduce(0, +),
            saturatedFat: validItems.compactMap { $0.calculatedNutrition?.saturatedFat }.reduce(0, +),
            omega3: validItems.compactMap { $0.calculatedNutrition?.omega3 }.reduce(0, +),
            omega6: validItems.compactMap { $0.calculatedNutrition?.omega6 }.reduce(0, +),
            sugar: validItems.compactMap { $0.calculatedNutrition?.sugar }.reduce(0, +),
            fiber: validItems.compactMap { $0.calculatedNutrition?.fiber }.reduce(0, +),
            sodium: validItems.compactMap { $0.calculatedNutrition?.sodium }.reduce(0, +),
            vitaminA: validItems.compactMap { $0.calculatedNutrition?.vitaminA }.reduce(0, +),
            vitaminC: validItems.compactMap { $0.calculatedNutrition?.vitaminC }.reduce(0, +),
            vitaminD: validItems.compactMap { $0.calculatedNutrition?.vitaminD }.reduce(0, +),
            calcium: validItems.compactMap { $0.calculatedNutrition?.calcium }.reduce(0, +),
            iron: validItems.compactMap { $0.calculatedNutrition?.iron }.reduce(0, +),
            potassium: validItems.compactMap { $0.calculatedNutrition?.potassium }.reduce(0, +)
        )
    }

    /// Number of items that have nutrition data
    var itemsWithNutrition: Int {
        items.filter { !$0.isSkipped && $0.calculatedNutrition != nil }.count
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        storeName: String? = nil,
        items: [PurchasedItem] = []
    ) {
        self.id = id
        self.date = date
        self.storeName = storeName
        self.items = items
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
