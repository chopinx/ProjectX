import Foundation

// MARK: - Main Food Categories

enum FoodMainCategory: String, Codable, CaseIterable, Identifiable {
    case vegetables, fruits, meat, seafood, dairy, grains, legumes, nutsSeeds, oils, snacks, beverages, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vegetables: return "Vegetables"
        case .fruits: return "Fruits"
        case .meat: return "Meat & Poultry"
        case .seafood: return "Seafood"
        case .dairy: return "Dairy & Eggs"
        case .grains: return "Grains & Bread"
        case .legumes: return "Legumes & Beans"
        case .nutsSeeds: return "Nuts & Seeds"
        case .oils: return "Oils & Fats"
        case .snacks: return "Snacks & Sweets"
        case .beverages: return "Beverages"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .vegetables: return "leaf.fill"
        case .fruits: return "apple.logo"
        case .meat: return "fork.knife"
        case .seafood: return "fish.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .grains: return "birthday.cake.fill"
        case .legumes: return "leaf.circle.fill"
        case .nutsSeeds: return "circle.hexagongrid.fill"
        case .oils: return "drop.fill"
        case .snacks: return "bag.fill"
        case .beverages: return "mug.fill"
        case .other: return "questionmark.circle.fill"
        }
    }

    var subcategories: [FoodSubcategory] {
        FoodSubcategory.allCases.filter { $0.parent == self }
    }
}

// MARK: - Subcategories

enum FoodSubcategory: String, Codable, CaseIterable, Identifiable {
    // Vegetables
    case leafyGreens, rootVegetables, cruciferous, otherVegetables
    // Fruits
    case freshFruits, berries, driedFruits
    // Meat
    case poultry, redMeat, processedMeat
    // Seafood
    case fish, shellfish
    // Dairy
    case milk, yogurt, cheese, eggs, butterCream
    // Grains
    case bread, pasta, rice, cereal, otherGrains
    // Legumes
    case beans, lentils, tofu
    // Nuts & Seeds
    case nuts, seeds
    // Oils
    case cookingOils, spreads
    // Snacks
    case chocolate, candy, chips, bakedTreats, iceCream
    // Beverages
    case water, coffeeAndTea, juice, soda, alcohol
    // Other
    case condiments, spices, otherFoods

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leafyGreens: return "Leafy Greens"
        case .rootVegetables: return "Root Vegetables"
        case .cruciferous: return "Cruciferous"
        case .otherVegetables: return "Other Vegetables"
        case .freshFruits: return "Fresh Fruits"
        case .berries: return "Berries"
        case .driedFruits: return "Dried Fruits"
        case .poultry: return "Poultry"
        case .redMeat: return "Red Meat"
        case .processedMeat: return "Processed Meat"
        case .fish: return "Fish"
        case .shellfish: return "Shellfish"
        case .milk: return "Milk"
        case .yogurt: return "Yogurt"
        case .cheese: return "Cheese"
        case .eggs: return "Eggs"
        case .butterCream: return "Butter & Cream"
        case .bread: return "Bread"
        case .pasta: return "Pasta"
        case .rice: return "Rice"
        case .cereal: return "Cereal"
        case .otherGrains: return "Other Grains"
        case .beans: return "Beans"
        case .lentils: return "Lentils"
        case .tofu: return "Tofu & Soy"
        case .nuts: return "Nuts"
        case .seeds: return "Seeds"
        case .cookingOils: return "Cooking Oils"
        case .spreads: return "Spreads"
        case .chocolate: return "Chocolate"
        case .candy: return "Candy"
        case .chips: return "Chips"
        case .bakedTreats: return "Baked Treats"
        case .iceCream: return "Ice Cream"
        case .water: return "Water"
        case .coffeeAndTea: return "Coffee & Tea"
        case .juice: return "Juice"
        case .soda: return "Soda"
        case .alcohol: return "Alcohol"
        case .condiments: return "Condiments"
        case .spices: return "Spices"
        case .otherFoods: return "Other"
        }
    }

    var parent: FoodMainCategory {
        switch self {
        case .leafyGreens, .rootVegetables, .cruciferous, .otherVegetables: return .vegetables
        case .freshFruits, .berries, .driedFruits: return .fruits
        case .poultry, .redMeat, .processedMeat: return .meat
        case .fish, .shellfish: return .seafood
        case .milk, .yogurt, .cheese, .eggs, .butterCream: return .dairy
        case .bread, .pasta, .rice, .cereal, .otherGrains: return .grains
        case .beans, .lentils, .tofu: return .legumes
        case .nuts, .seeds: return .nutsSeeds
        case .cookingOils, .spreads: return .oils
        case .chocolate, .candy, .chips, .bakedTreats, .iceCream: return .snacks
        case .water, .coffeeAndTea, .juice, .soda, .alcohol: return .beverages
        case .condiments, .spices, .otherFoods: return .other
        }
    }
}

// MARK: - Food Category (Combined)

struct FoodCategory: Codable, Hashable {
    var main: FoodMainCategory
    var sub: FoodSubcategory?

    init(main: FoodMainCategory, sub: FoodSubcategory? = nil) {
        self.main = main
        self.sub = sub
    }

    init(fromString string: String) {
        let lowercased = string.lowercased()

        // Try main category
        if let main = FoodMainCategory.allCases.first(where: {
            $0.rawValue.lowercased() == lowercased || $0.displayName.lowercased() == lowercased
        }) {
            self.main = main
            self.sub = nil
            return
        }

        // Try subcategory
        if let sub = FoodSubcategory.allCases.first(where: {
            $0.rawValue.lowercased() == lowercased || $0.displayName.lowercased() == lowercased
        }) {
            self.main = sub.parent
            self.sub = sub
            return
        }

        // Common mappings
        switch lowercased {
        case "produce": self = FoodCategory(main: .vegetables)
        case "protein", "proteins": self = FoodCategory(main: .meat)
        case "chicken", "turkey": self = FoodCategory(main: .meat, sub: .poultry)
        case "beef", "pork", "lamb": self = FoodCategory(main: .meat, sub: .redMeat)
        case "salmon", "tuna", "cod": self = FoodCategory(main: .seafood, sub: .fish)
        case "shrimp", "crab", "lobster": self = FoodCategory(main: .seafood, sub: .shellfish)
        case "bakery": self = FoodCategory(main: .grains, sub: .bread)
        default: self = FoodCategory(main: .other)
        }
    }

    init(rawValue: String) {
        let parts = rawValue.split(separator: "/").map(String.init)
        self.main = parts.first.flatMap { FoodMainCategory(rawValue: $0) } ?? .other
        self.sub = parts.count > 1 ? FoodSubcategory(rawValue: parts[1]) : nil
    }

    var displayName: String { sub?.displayName ?? main.displayName }
    var fullPath: String { sub != nil ? "\(main.displayName) > \(sub!.displayName)" : main.displayName }
    var icon: String { main.icon }
    var rawValue: String { sub != nil ? "\(main.rawValue)/\(sub!.rawValue)" : main.rawValue }

    static var other: FoodCategory { FoodCategory(main: .other) }
}
