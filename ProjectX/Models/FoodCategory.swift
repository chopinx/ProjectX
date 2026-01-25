import Foundation

// MARK: - Main Food Categories (Diet-Management Focused)

enum FoodMainCategory: String, Codable, CaseIterable, Identifiable {
    case proteins
    case vegetables
    case fruits
    case dairy
    case grains
    case legumes
    case healthyFats
    case beverages
    case treats
    case condiments
    case prepared
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .proteins: return "Proteins"
        case .vegetables: return "Vegetables"
        case .fruits: return "Fruits"
        case .dairy: return "Dairy & Alternatives"
        case .grains: return "Grains & Starches"
        case .legumes: return "Legumes"
        case .healthyFats: return "Healthy Fats"
        case .beverages: return "Beverages"
        case .treats: return "Treats & Snacks"
        case .condiments: return "Condiments"
        case .prepared: return "Prepared Foods"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .proteins: return "fork.knife"
        case .vegetables: return "carrot.fill"
        case .fruits: return "apple.logo"
        case .dairy: return "cup.and.saucer.fill"
        case .grains: return "birthday.cake.fill"
        case .legumes: return "leaf.fill"
        case .healthyFats: return "drop.fill"
        case .beverages: return "mug.fill"
        case .treats: return "gift.fill"
        case .condiments: return "flame.fill"
        case .prepared: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Brief description for diet guidance
    var dietTip: String {
        switch self {
        case .proteins: return "Essential for muscle & satiety"
        case .vegetables: return "Low calorie, high fiber & nutrients"
        case .fruits: return "Natural sugars & vitamins"
        case .dairy: return "Calcium & protein source"
        case .grains: return "Energy from carbohydrates"
        case .legumes: return "Plant protein & fiber"
        case .healthyFats: return "Essential fatty acids"
        case .beverages: return "Hydration & energy"
        case .treats: return "Occasional indulgences"
        case .condiments: return "Flavor enhancers"
        case .prepared: return "Convenience foods"
        case .other: return "Miscellaneous items"
        }
    }

    var subcategories: [FoodSubcategory] {
        FoodSubcategory.allCases.filter { $0.parent == self }
    }
}

// MARK: - Subcategories (Diet-Aware Groupings)

enum FoodSubcategory: String, Codable, CaseIterable, Identifiable {
    // Proteins - organized by leanness/source
    case leanMeat          // Chicken breast, turkey, lean cuts
    case redMeat           // Beef, pork, lamb
    case seafood           // Fish & shellfish
    case eggs              // Whole eggs, egg whites
    case plantProtein      // Tofu, tempeh, seitan

    // Vegetables - organized by carb content
    case leafyGreens       // Spinach, kale, lettuce (very low cal)
    case cruciferous       // Broccoli, cauliflower, cabbage
    case starchyVegetables // Potato, corn, peas (higher carb)
    case otherVegetables   // Tomato, pepper, cucumber, etc.

    // Fruits - organized by sugar content
    case berries           // Low sugar, high antioxidants
    case citrus            // Vitamin C rich
    case tropicalFruits    // Mango, pineapple, banana
    case driedFruits       // High sugar concentration

    // Dairy - organized by fat content
    case milkAlternatives  // Milk, oat milk, almond milk
    case yogurtFermented   // Yogurt, kefir, skyr
    case cheese            // All cheese types
    case butterCream       // High fat dairy

    // Grains - organized by processing
    case wholeGrains       // Brown rice, quinoa, oats
    case refinedGrains     // White rice, white bread
    case breadBakery       // Breads, rolls, bagels
    case pastaNoodles      // Pasta, noodles, couscous

    // Legumes
    case beansLentils      // Beans, lentils, chickpeas
    case soyProducts       // Tofu, tempeh, edamame

    // Healthy Fats
    case nuts              // Almonds, walnuts, cashews
    case seeds             // Chia, flax, pumpkin seeds
    case oils              // Olive oil, avocado oil
    case nutButters        // Peanut butter, almond butter

    // Beverages
    case water             // Plain, sparkling, flavored
    case coffeeTea         // Coffee, tea, matcha
    case juiceSmoothies    // Fruit juice, smoothies
    case softDrinks        // Soda, energy drinks
    case alcohol           // Beer, wine, spirits

    // Treats & Snacks
    case chocolateCandy    // Chocolate, candy
    case chipsSavory       // Chips, crackers, pretzels
    case bakedGoods        // Cookies, cakes, pastries
    case frozenTreats      // Ice cream, frozen yogurt

    // Condiments
    case saucesDressings   // Ketchup, mayo, salad dressing
    case spicesHerbs       // Seasonings, dried herbs
    case sweeteners        // Sugar, honey, artificial

    // Prepared Foods
    case frozenMeals       // TV dinners, frozen entrees
    case cannedFoods       // Canned soup, vegetables
    case readyToEat        // Deli items, rotisserie

    // Other
    case supplements       // Protein powder, vitamins
    case otherFoods        // Miscellaneous

    var id: String { rawValue }

    var displayName: String {
        switch self {
        // Proteins
        case .leanMeat: return "Lean Meat"
        case .redMeat: return "Red Meat"
        case .seafood: return "Seafood"
        case .eggs: return "Eggs"
        case .plantProtein: return "Plant Protein"
        // Vegetables
        case .leafyGreens: return "Leafy Greens"
        case .cruciferous: return "Cruciferous"
        case .starchyVegetables: return "Starchy Vegetables"
        case .otherVegetables: return "Other Vegetables"
        // Fruits
        case .berries: return "Berries"
        case .citrus: return "Citrus"
        case .tropicalFruits: return "Tropical & Other"
        case .driedFruits: return "Dried Fruits"
        // Dairy
        case .milkAlternatives: return "Milk & Alternatives"
        case .yogurtFermented: return "Yogurt & Fermented"
        case .cheese: return "Cheese"
        case .butterCream: return "Butter & Cream"
        // Grains
        case .wholeGrains: return "Whole Grains"
        case .refinedGrains: return "Refined Grains"
        case .breadBakery: return "Bread & Bakery"
        case .pastaNoodles: return "Pasta & Noodles"
        // Legumes
        case .beansLentils: return "Beans & Lentils"
        case .soyProducts: return "Soy Products"
        // Healthy Fats
        case .nuts: return "Nuts"
        case .seeds: return "Seeds"
        case .oils: return "Oils"
        case .nutButters: return "Nut Butters"
        // Beverages
        case .water: return "Water"
        case .coffeeTea: return "Coffee & Tea"
        case .juiceSmoothies: return "Juice & Smoothies"
        case .softDrinks: return "Soft Drinks"
        case .alcohol: return "Alcohol"
        // Treats
        case .chocolateCandy: return "Chocolate & Candy"
        case .chipsSavory: return "Chips & Savory"
        case .bakedGoods: return "Baked Goods"
        case .frozenTreats: return "Frozen Treats"
        // Condiments
        case .saucesDressings: return "Sauces & Dressings"
        case .spicesHerbs: return "Spices & Herbs"
        case .sweeteners: return "Sweeteners"
        // Prepared
        case .frozenMeals: return "Frozen Meals"
        case .cannedFoods: return "Canned Foods"
        case .readyToEat: return "Ready-to-Eat"
        // Other
        case .supplements: return "Supplements"
        case .otherFoods: return "Other"
        }
    }

    /// Diet guidance for this subcategory
    var dietTip: String {
        switch self {
        case .leanMeat: return "High protein, low fat"
        case .redMeat: return "Iron-rich, moderate intake"
        case .seafood: return "Omega-3 fatty acids"
        case .eggs: return "Complete protein source"
        case .plantProtein: return "Fiber + protein combo"
        case .leafyGreens: return "Very low calorie, nutrient dense"
        case .cruciferous: return "Anti-inflammatory benefits"
        case .starchyVegetables: return "Higher carbs, good fiber"
        case .otherVegetables: return "Vitamins & minerals"
        case .berries: return "Low sugar, high antioxidants"
        case .citrus: return "Vitamin C rich"
        case .tropicalFruits: return "Natural energy, vitamins"
        case .driedFruits: return "Concentrated sugars"
        case .milkAlternatives: return "Calcium source"
        case .yogurtFermented: return "Probiotics for gut health"
        case .cheese: return "Protein & calcium, watch portions"
        case .butterCream: return "High in saturated fat"
        case .wholeGrains: return "Fiber & sustained energy"
        case .refinedGrains: return "Quick energy, less fiber"
        case .breadBakery: return "Watch portion sizes"
        case .pastaNoodles: return "Carb-heavy, pair with protein"
        case .beansLentils: return "Fiber + plant protein"
        case .soyProducts: return "Complete plant protein"
        case .nuts: return "Heart-healthy fats"
        case .seeds: return "Omega-3s & fiber"
        case .oils: return "Use in moderation"
        case .nutButters: return "Protein & healthy fats"
        case .water: return "Zero calories, essential"
        case .coffeeTea: return "Low cal, watch additions"
        case .juiceSmoothies: return "Can be high in sugar"
        case .softDrinks: return "Empty calories"
        case .alcohol: return "Limit consumption"
        case .chocolateCandy: return "Occasional treat"
        case .chipsSavory: return "High sodium, watch portions"
        case .bakedGoods: return "High in sugar & fat"
        case .frozenTreats: return "Occasional indulgence"
        case .saucesDressings: return "Hidden calories"
        case .spicesHerbs: return "Zero calorie flavor"
        case .sweeteners: return "Use sparingly"
        case .frozenMeals: return "Check sodium & portions"
        case .cannedFoods: return "Watch sodium content"
        case .readyToEat: return "Convenience vs nutrition"
        case .supplements: return "Supplement, not replace"
        case .otherFoods: return ""
        }
    }

    var parent: FoodMainCategory {
        switch self {
        case .leanMeat, .redMeat, .seafood, .eggs, .plantProtein:
            return .proteins
        case .leafyGreens, .cruciferous, .starchyVegetables, .otherVegetables:
            return .vegetables
        case .berries, .citrus, .tropicalFruits, .driedFruits:
            return .fruits
        case .milkAlternatives, .yogurtFermented, .cheese, .butterCream:
            return .dairy
        case .wholeGrains, .refinedGrains, .breadBakery, .pastaNoodles:
            return .grains
        case .beansLentils, .soyProducts:
            return .legumes
        case .nuts, .seeds, .oils, .nutButters:
            return .healthyFats
        case .water, .coffeeTea, .juiceSmoothies, .softDrinks, .alcohol:
            return .beverages
        case .chocolateCandy, .chipsSavory, .bakedGoods, .frozenTreats:
            return .treats
        case .saucesDressings, .spicesHerbs, .sweeteners:
            return .condiments
        case .frozenMeals, .cannedFoods, .readyToEat:
            return .prepared
        case .supplements, .otherFoods:
            return .other
        }
    }
}

// MARK: - Food Category (Combined)

struct FoodCategory: Codable, Hashable {
    var main: FoodMainCategory
    var sub: FoodSubcategory?
    var customSub: String?

    init(main: FoodMainCategory, sub: FoodSubcategory? = nil, customSub: String? = nil) {
        self.main = main
        self.sub = sub
        self.customSub = customSub
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

        // Common food mappings for diet management
        switch lowercased {
        // Proteins
        case "chicken", "turkey", "chicken breast":
            self = FoodCategory(main: .proteins, sub: .leanMeat)
        case "beef", "pork", "lamb", "steak":
            self = FoodCategory(main: .proteins, sub: .redMeat)
        case "salmon", "tuna", "cod", "fish", "shrimp":
            self = FoodCategory(main: .proteins, sub: .seafood)
        case "egg", "eggs":
            self = FoodCategory(main: .proteins, sub: .eggs)
        case "tofu", "tempeh":
            self = FoodCategory(main: .proteins, sub: .plantProtein)
        // Vegetables
        case "spinach", "kale", "lettuce", "salad":
            self = FoodCategory(main: .vegetables, sub: .leafyGreens)
        case "broccoli", "cauliflower":
            self = FoodCategory(main: .vegetables, sub: .cruciferous)
        case "potato", "corn", "peas":
            self = FoodCategory(main: .vegetables, sub: .starchyVegetables)
        // Fruits
        case "strawberry", "blueberry", "raspberry":
            self = FoodCategory(main: .fruits, sub: .berries)
        case "orange", "lemon", "grapefruit":
            self = FoodCategory(main: .fruits, sub: .citrus)
        case "banana", "mango", "pineapple":
            self = FoodCategory(main: .fruits, sub: .tropicalFruits)
        // Dairy
        case "milk", "oat milk", "almond milk":
            self = FoodCategory(main: .dairy, sub: .milkAlternatives)
        case "yogurt", "greek yogurt":
            self = FoodCategory(main: .dairy, sub: .yogurtFermented)
        case "cheese", "cheddar", "mozzarella":
            self = FoodCategory(main: .dairy, sub: .cheese)
        // Grains
        case "oats", "oatmeal", "quinoa", "brown rice":
            self = FoodCategory(main: .grains, sub: .wholeGrains)
        case "white rice", "white bread":
            self = FoodCategory(main: .grains, sub: .refinedGrains)
        case "bread", "bagel", "roll":
            self = FoodCategory(main: .grains, sub: .breadBakery)
        case "pasta", "spaghetti", "noodles":
            self = FoodCategory(main: .grains, sub: .pastaNoodles)
        // Healthy Fats
        case "almonds", "walnuts", "cashews":
            self = FoodCategory(main: .healthyFats, sub: .nuts)
        case "olive oil", "avocado oil":
            self = FoodCategory(main: .healthyFats, sub: .oils)
        case "peanut butter", "almond butter":
            self = FoodCategory(main: .healthyFats, sub: .nutButters)
        // Beverages
        case "coffee", "tea":
            self = FoodCategory(main: .beverages, sub: .coffeeTea)
        case "juice", "smoothie":
            self = FoodCategory(main: .beverages, sub: .juiceSmoothies)
        case "soda", "cola":
            self = FoodCategory(main: .beverages, sub: .softDrinks)
        // Default
        default:
            self = FoodCategory(main: .other)
        }
    }

    init(rawValue: String) {
        let parts = rawValue.split(separator: "/").map(String.init)
        self.main = parts.first.flatMap { FoodMainCategory(rawValue: $0) } ?? .other
        if parts.count > 1 {
            let subPart = parts[1]
            if subPart.hasPrefix("custom:") {
                self.customSub = String(subPart.dropFirst(7))
                self.sub = nil
            } else {
                self.sub = FoodSubcategory(rawValue: subPart)
                self.customSub = nil
            }
        } else {
            self.sub = nil
            self.customSub = nil
        }
    }

    var displayName: String { customSub ?? sub?.displayName ?? main.displayName }
    var fullPath: String {
        if let custom = customSub { return "\(main.displayName) > \(custom)" }
        if let sub = sub { return "\(main.displayName) > \(sub.displayName)" }
        return main.displayName
    }
    var icon: String { main.icon }
    var rawValue: String {
        if let custom = customSub { return "\(main.rawValue)/custom:\(custom)" }
        if let sub = sub { return "\(main.rawValue)/\(sub.rawValue)" }
        return main.rawValue
    }
    var hasSubcategory: Bool { sub != nil || customSub != nil }

    /// Diet tip for this category
    var dietTip: String { sub?.dietTip ?? main.dietTip }

    static var other: FoodCategory { FoodCategory(main: .other) }
}
