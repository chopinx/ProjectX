import Foundation
import SwiftData

// MARK: - Meal Type

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .lunch: "sun.max.fill"
        case .dinner: "moon.stars.fill"
        case .snack: "carrot.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .dinner: 2
        case .snack: 3
        }
    }

    var defaultTime: (hour: Int, minute: Int) {
        switch self {
        case .breakfast: (8, 0)
        case .lunch: (12, 30)
        case .dinner: (19, 0)
        case .snack: (15, 0)
        }
    }
}

// MARK: - Meal

@Model
final class Meal {
    @Attribute(.unique) var id: UUID
    var date: Date
    var mealType: MealType
    var notes: String?
    @Relationship(deleteRule: .cascade, inverse: \MealItem.meal) var items: [MealItem]
    var profile: Profile?
    var createdAt: Date
    var updatedAt: Date

    /// Total nutrition for all non-skipped items with linked foods
    var totalNutrition: NutritionInfo {
        NutritionInfo.sum(items.filter { !$0.isSkipped }.map(\.calculatedNutrition))
    }

    /// Number of items that have nutrition data
    var itemsWithNutrition: Int {
        items.filter { !$0.isSkipped && $0.calculatedNutrition != nil }.count
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType = .lunch,
        notes: String? = nil,
        items: [MealItem] = []
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.notes = notes
        self.items = items
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Meal Item

@Model
final class MealItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double  // Always in grams
    var food: Food?
    var meal: Meal?
    var isSkipped: Bool

    /// Calculate nutrition for this item based on quantity (in grams)
    var calculatedNutrition: NutritionInfo? {
        food?.nutrition?.scaled(byGrams: quantity)
    }

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double = 100,  // Default 100g
        food: Food? = nil,
        isSkipped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.food = food
        self.isSkipped = isSkipped
    }
}
