import Foundation
import SwiftData

@Model
final class CustomSubcategory {
    var name: String
    var mainCategoryRaw: String
    var createdAt: Date

    init(name: String, mainCategory: FoodMainCategory) {
        self.name = name
        self.mainCategoryRaw = mainCategory.rawValue
        self.createdAt = .now
    }

    var mainCategory: FoodMainCategory? {
        FoodMainCategory(rawValue: mainCategoryRaw)
    }
}
