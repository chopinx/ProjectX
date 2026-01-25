import SwiftUI

// MARK: - App Color Theme
// A fresh, modern color palette inspired by nature and nutrition

extension Color {
    // MARK: - Primary Colors
    /// Main brand color - Fresh teal green
    static let themePrimary = Color(hex: "10B981")!  // Emerald green
    /// Darker variant for contrast
    static let themePrimaryDark = Color(hex: "059669")!

    // MARK: - Secondary Colors
    /// Warm accent - Coral orange
    static let themeSecondary = Color(hex: "F97316")!  // Orange
    /// Lighter variant
    static let themeSecondaryLight = Color(hex: "FB923C")!

    // MARK: - Semantic Colors
    /// Success - Bright green
    static let themeSuccess = Color(hex: "22C55E")!
    /// Warning - Amber
    static let themeWarning = Color(hex: "F59E0B")!
    /// Error - Rose red
    static let themeError = Color(hex: "EF4444")!
    /// Info - Sky blue
    static let themeInfo = Color(hex: "0EA5E9")!

    // MARK: - Neutral Colors
    static let themeBackground = Color(hex: "F8FAFC")!
    static let themeCardBackground = Color(hex: "FFFFFF")!
    static let themeBorder = Color(hex: "E2E8F0")!
    static let themeTextPrimary = Color(hex: "1E293B")!
    static let themeTextSecondary = Color(hex: "64748B")!
    static let themeTextTertiary = Color(hex: "94A3B8")!

    // MARK: - Category Colors (for food categories)
    static let categoryVegetables = Color(hex: "22C55E")!  // Green
    static let categoryFruits = Color(hex: "F97316")!      // Orange
    static let categoryMeat = Color(hex: "EF4444")!        // Red
    static let categorySeafood = Color(hex: "0EA5E9")!     // Blue
    static let categoryDairy = Color(hex: "FBBF24")!       // Yellow
    static let categoryGrains = Color(hex: "D97706")!      // Amber
    static let categoryLegumes = Color(hex: "84CC16")!     // Lime
    static let categoryNuts = Color(hex: "A16207")!        // Brown
    static let categoryOils = Color(hex: "FACC15")!        // Gold
    static let categorySnacks = Color(hex: "EC4899")!      // Pink
    static let categoryBeverages = Color(hex: "06B6D4")!   // Cyan
    static let categoryOther = Color(hex: "6B7280")!       // Gray

    // MARK: - Nutrition Colors
    static let nutritionCalories = Color(hex: "F97316")!   // Orange
    static let nutritionProtein = Color(hex: "3B82F6")!    // Blue
    static let nutritionCarbs = Color(hex: "F59E0B")!      // Amber
    static let nutritionFat = Color(hex: "EF4444")!        // Red
    static let nutritionSugar = Color(hex: "EC4899")!      // Pink
    static let nutritionFiber = Color(hex: "22C55E")!      // Green
    static let nutritionSodium = Color(hex: "8B5CF6")!     // Purple

    // MARK: - Gradient
    static var themePrimaryGradient: LinearGradient {
        LinearGradient(
            colors: [themePrimary, Color(hex: "14B8A6")!],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Category Color Extension

extension FoodMainCategory {
    var themeColor: Color {
        switch self {
        case .vegetables: return .categoryVegetables
        case .fruits: return .categoryFruits
        case .meat: return .categoryMeat
        case .seafood: return .categorySeafood
        case .dairy: return .categoryDairy
        case .grains: return .categoryGrains
        case .legumes: return .categoryLegumes
        case .nutsSeeds: return .categoryNuts
        case .oils: return .categoryOils
        case .snacks: return .categorySnacks
        case .beverages: return .categoryBeverages
        case .other: return .categoryOther
        }
    }
}

// MARK: - View Modifiers

struct ThemedCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ThemedButtonModifier: ViewModifier {
    var style: ButtonStyleType = .primary

    enum ButtonStyleType {
        case primary, secondary, destructive
    }

    func body(content: Content) -> some View {
        content
            .fontWeight(.semibold)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .themePrimary
        case .secondary: return .themeSecondary
        case .destructive: return .themeError
        }
    }

    private var foregroundColor: Color {
        .white
    }
}

extension View {
    func themedCard() -> some View {
        modifier(ThemedCardModifier())
    }

    func themedButton(_ style: ThemedButtonModifier.ButtonStyleType = .primary) -> some View {
        modifier(ThemedButtonModifier(style: style))
    }
}
