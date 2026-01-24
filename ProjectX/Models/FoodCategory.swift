import Foundation

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case produce
    case dairy
    case meat
    case seafood
    case bakery
    case beverages
    case snacks
    case frozen
    case pantry
    case other

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .meat: return "fork.knife"
        case .seafood: return "fish.fill"
        case .bakery: return "birthday.cake.fill"
        case .beverages: return "mug.fill"
        case .snacks: return "popcorn.fill"
        case .frozen: return "snowflake"
        case .pantry: return "cabinet.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
}
