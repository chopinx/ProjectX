import Foundation

// MARK: - Activity Level

enum ActivityLevel: String, CaseIterable, Identifiable, Codable {
    case sedentary = "Sedentary"
    case light = "Lightly Active"
    case moderate = "Moderately Active"
    case active = "Active"
    case veryActive = "Very Active"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .sedentary: return "Little or no exercise"
        case .light: return "Light exercise 1-3 days/week"
        case .moderate: return "Moderate exercise 3-5 days/week"
        case .active: return "Hard exercise 6-7 days/week"
        case .veryActive: return "Very hard exercise, physical job"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    /// Baseline nutrition for 60kg adult
    var baseline: (cal: Int, pro: Int, carb: Int, fat: Int) {
        let cal = Int(1400.0 * multiplier)
        return (cal, 60, Int(Double(cal) * 0.50 / 4), Int(Double(cal) * 0.30 / 9))
    }
}

// MARK: - Diet Type

enum DietType: String, CaseIterable, Identifiable, Codable {
    case standard = "Standard"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case keto = "Keto/Low-Carb"
    case mediterranean = "Mediterranean"
    case highProtein = "High Protein"
    case lowSodium = "Low Sodium"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .standard: return "Balanced macros, no restrictions"
        case .vegetarian: return "No meat, includes dairy/eggs"
        case .vegan: return "No animal products"
        case .keto: return "Very low carb, high fat"
        case .mediterranean: return "High in olive oil, fish, vegetables"
        case .highProtein: return "Higher protein for muscle building"
        case .lowSodium: return "Reduced sodium intake"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "fork.knife"
        case .vegetarian: return "leaf"
        case .vegan: return "leaf.fill"
        case .keto: return "flame"
        case .mediterranean: return "fish"
        case .highProtein: return "dumbbell"
        case .lowSodium: return "drop.triangle"
        }
    }
}

// MARK: - Family Member

struct FamilyMember: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var age: Int
    var weight: Double  // kg
    var activityLevel: ActivityLevel
    var dietType: DietType

    init(id: UUID = UUID(), name: String = "", age: Int = 30, weight: Double = 70, activityLevel: ActivityLevel = .moderate, dietType: DietType = .standard) {
        self.id = id
        self.name = name
        self.age = age
        self.weight = weight
        self.activityLevel = activityLevel
        self.dietType = dietType
    }

    /// Estimated daily calories based on Mifflin-St Jeor equation
    var estimatedCalories: Int {
        // Simplified BMR calculation (average of male/female formulas)
        let bmr = 10 * weight + 6.25 * 170 - 5 * Double(age) + 5  // Assuming 170cm average height
        return Int(bmr * activityLevel.multiplier)
    }
}
