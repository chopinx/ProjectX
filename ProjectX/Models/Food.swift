import Foundation
import SwiftData

@Model
final class Food {
    @Attribute(.unique) var id: UUID
    var name: String
    var categoryRaw: String
    @Relationship(deleteRule: .cascade) var nutrition: NutritionInfo?
    var isUserCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory = .other,
        nutrition: NutritionInfo? = nil,
        isUserCreated: Bool = true
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.nutrition = nutrition
        self.isUserCreated = isUserCreated
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
