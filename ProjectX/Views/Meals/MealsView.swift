import SwiftUI
import SwiftData

struct MealsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Meal.date, order: .reverse) private var allMeals: [Meal]
    @Bindable var settings: AppSettings
    @State private var mealToDelete: Meal?

    init(settings: AppSettings) {
        self.settings = settings
    }

    private var meals: [Meal] {
        guard let profileId = settings.activeProfileId else { return allMeals }
        return allMeals.filter { $0.profile?.id == profileId }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack {
            List {
                if meals.isEmpty {
                    ContentUnavailableView(
                        "No Meals Yet",
                        systemImage: "fork.knife.circle",
                        description: Text("Use the + button to log your first meal")
                    )
                } else {
                    ForEach(meals) { meal in
                        NavigationLink {
                            MealDetailView(meal: meal, settings: settings)
                        } label: {
                            MealRow(meal: meal)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                DispatchQueue.main.async { mealToDelete = meal }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
            .navigationTitle("Meals")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileToolbarButton(settings: settings)
                }
            }
        }
        .deleteConfirmation("Delete Meal?", item: $mealToDelete, message: { meal in
            "Delete \(meal.mealType.rawValue) with \(meal.items.count) item\(meal.items.count == 1 ? "" : "s")? This cannot be undone."
        }) { meal in
            context.delete(meal)
            try? context.save()
        }
    }
}

// MARK: - Meal Row

private struct MealRow: View {
    let meal: Meal

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: meal.mealType.icon)
                    .foregroundStyle(mealTypeColor)
                Text(meal.mealType.rawValue)
                    .font(.headline)
                Spacer()
                Text(Self.timeFormatter.string(from: meal.date))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(Self.dateFormatter.string(from: meal.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(meal.items.count) item\(meal.items.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Show nutrition if any items have nutrition data
            if meal.itemsWithNutrition > 0 {
                NutritionSummaryRow(nutrition: meal.totalNutrition, isCompact: false)
            }
        }
        .padding(.vertical, 2)
    }

    private var mealTypeColor: Color {
        switch meal.mealType {
        case .breakfast: .themeSecondary
        case .lunch: .themeWarning
        case .dinner: .themePrimaryDark
        case .snack: .themeSuccess
        }
    }
}
