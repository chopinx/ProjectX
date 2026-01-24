import Foundation

// MARK: - Level 1: Main Food Groups

enum FoodMainCategory: String, Codable, CaseIterable, Identifiable {
    case vegetables
    case fruits
    case meat
    case seafood
    case dairy
    case grains
    case legumes
    case nutsSeeds
    case oils
    case snacks
    case beverages
    case other

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

    var healthNote: String {
        switch self {
        case .vegetables: return "Nutrient-dense, eat freely"
        case .fruits: return "Natural sugars, vitamins & fiber"
        case .meat: return "Protein source, vary choices"
        case .seafood: return "Omega-3, lean protein"
        case .dairy: return "Calcium & protein"
        case .grains: return "Energy, prefer whole grains"
        case .legumes: return "Protein + fiber combo"
        case .nutsSeeds: return "Healthy fats, in moderation"
        case .oils: return "Essential, use sparingly"
        case .snacks: return "Occasional treats"
        case .beverages: return "Hydration matters"
        case .other: return ""
        }
    }

    var subcategories: [FoodSubcategory] {
        FoodSubcategory.allCases.filter { $0.parent == self }
    }
}

// MARK: - Level 2: Subcategories

enum FoodSubcategory: String, Codable, CaseIterable, Identifiable {
    // Vegetables
    case leafyGreens        // Spinach, kale, lettuce
    case rootVegetables     // Carrots, potatoes, beets
    case cruciferous        // Broccoli, cauliflower
    case otherVegetables

    // Fruits
    case freshFruits
    case berries
    case driedFruits

    // Meat
    case poultry            // Chicken, turkey
    case redMeat            // Beef, pork, lamb
    case processedMeat      // Sausage, bacon, deli

    // Seafood
    case fish
    case shellfish

    // Dairy
    case milk
    case yogurt
    case cheese
    case eggs
    case butterCream

    // Grains
    case bread
    case pasta
    case rice
    case cereal
    case otherGrains

    // Legumes
    case beans
    case lentils
    case tofu               // Soy products

    // Nuts & Seeds
    case nuts
    case seeds

    // Oils
    case cookingOils
    case spreads            // Butter, margarine

    // Snacks
    case chocolate
    case candy
    case chips
    case bakedTreats        // Cookies, cakes
    case iceCream

    // Beverages
    case water
    case coffeeAndTea
    case juice
    case soda
    case alcohol

    // Other
    case condiments
    case spices
    case otherFoods

    var id: String { rawValue }

    var displayName: String {
        switch self {
        // Vegetables
        case .leafyGreens: return "Leafy Greens"
        case .rootVegetables: return "Root Vegetables"
        case .cruciferous: return "Cruciferous"
        case .otherVegetables: return "Other Vegetables"
        // Fruits
        case .freshFruits: return "Fresh Fruits"
        case .berries: return "Berries"
        case .driedFruits: return "Dried Fruits"
        // Meat
        case .poultry: return "Poultry"
        case .redMeat: return "Red Meat"
        case .processedMeat: return "Processed Meat"
        // Seafood
        case .fish: return "Fish"
        case .shellfish: return "Shellfish"
        // Dairy
        case .milk: return "Milk"
        case .yogurt: return "Yogurt"
        case .cheese: return "Cheese"
        case .eggs: return "Eggs"
        case .butterCream: return "Butter & Cream"
        // Grains
        case .bread: return "Bread"
        case .pasta: return "Pasta"
        case .rice: return "Rice"
        case .cereal: return "Cereal"
        case .otherGrains: return "Other Grains"
        // Legumes
        case .beans: return "Beans"
        case .lentils: return "Lentils"
        case .tofu: return "Tofu & Soy"
        // Nuts & Seeds
        case .nuts: return "Nuts"
        case .seeds: return "Seeds"
        // Oils
        case .cookingOils: return "Cooking Oils"
        case .spreads: return "Spreads"
        // Snacks
        case .chocolate: return "Chocolate"
        case .candy: return "Candy"
        case .chips: return "Chips"
        case .bakedTreats: return "Baked Treats"
        case .iceCream: return "Ice Cream"
        // Beverages
        case .water: return "Water"
        case .coffeeAndTea: return "Coffee & Tea"
        case .juice: return "Juice"
        case .soda: return "Soda"
        case .alcohol: return "Alcohol"
        // Other
        case .condiments: return "Condiments"
        case .spices: return "Spices"
        case .otherFoods: return "Other"
        }
    }

    var healthNote: String? {
        switch self {
        case .leafyGreens: return "Rich in vitamins A, C, K"
        case .berries: return "High antioxidants"
        case .fish: return "Omega-3 fatty acids"
        case .redMeat: return "Limit to 1-2x per week"
        case .processedMeat: return "High sodium, limit intake"
        case .driedFruits: return "Concentrated sugar, watch portions"
        case .yogurt: return "Probiotics for gut health"
        case .lentils: return "High protein & fiber"
        case .nuts: return "Healthy fats, heart friendly"
        case .soda: return "Empty calories, limit"
        case .alcohol: return "Moderate consumption"
        default: return nil
        }
    }

    var parent: FoodMainCategory {
        switch self {
        case .leafyGreens, .rootVegetables, .cruciferous, .otherVegetables:
            return .vegetables
        case .freshFruits, .berries, .driedFruits:
            return .fruits
        case .poultry, .redMeat, .processedMeat:
            return .meat
        case .fish, .shellfish:
            return .seafood
        case .milk, .yogurt, .cheese, .eggs, .butterCream:
            return .dairy
        case .bread, .pasta, .rice, .cereal, .otherGrains:
            return .grains
        case .beans, .lentils, .tofu:
            return .legumes
        case .nuts, .seeds:
            return .nutsSeeds
        case .cookingOils, .spreads:
            return .oils
        case .chocolate, .candy, .chips, .bakedTreats, .iceCream:
            return .snacks
        case .water, .coffeeAndTea, .juice, .soda, .alcohol:
            return .beverages
        case .condiments, .spices, .otherFoods:
            return .other
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

    /// Create from a simple string (for LLM responses and backward compatibility)
    init(fromString string: String) {
        let lowercased = string.lowercased()

        // Try to match main category
        if let main = FoodMainCategory.allCases.first(where: {
            $0.rawValue.lowercased() == lowercased ||
            $0.displayName.lowercased() == lowercased
        }) {
            self.main = main
            self.sub = nil
            return
        }

        // Try to match subcategory
        if let sub = FoodSubcategory.allCases.first(where: {
            $0.rawValue.lowercased() == lowercased ||
            $0.displayName.lowercased() == lowercased
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
        case "frozen": self = FoodCategory(main: .other)
        case "pantry": self = FoodCategory(main: .other)
        case "snacks", "treats": self = FoodCategory(main: .snacks)
        default: self = FoodCategory(main: .other)
        }
    }

    var displayName: String {
        if let sub = sub {
            return sub.displayName
        }
        return main.displayName
    }

    var fullPath: String {
        if let sub = sub {
            return "\(main.displayName) > \(sub.displayName)"
        }
        return main.displayName
    }

    var icon: String {
        main.icon
    }

    var healthNote: String {
        if let sub = sub, let note = sub.healthNote {
            return note
        }
        return main.healthNote
    }

    /// String representation for storage
    var rawValue: String {
        if let sub = sub {
            return "\(main.rawValue)/\(sub.rawValue)"
        }
        return main.rawValue
    }

    /// Create from stored string
    init(rawValue: String) {
        let parts = rawValue.split(separator: "/").map(String.init)

        if let mainStr = parts.first,
           let main = FoodMainCategory(rawValue: mainStr) {
            self.main = main
        } else {
            self.main = .other
        }

        if parts.count > 1,
           let sub = FoodSubcategory(rawValue: parts[1]) {
            self.sub = sub
        } else {
            self.sub = nil
        }
    }

    static var other: FoodCategory {
        FoodCategory(main: .other)
    }
}
