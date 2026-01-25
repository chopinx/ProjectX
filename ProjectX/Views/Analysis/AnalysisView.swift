import SwiftUI
import SwiftData

struct AnalysisView: View {
    @Query(sort: \GroceryTrip.date) private var trips: [GroceryTrip]
    @State private var settings = AppSettings()

    private var lastMonthRange: ClosedRange<Date> {
        let now = Date()
        let start = Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now
        return start...now
    }

    private var yearToDateRange: ClosedRange<Date> {
        let now = Date()
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.year], from: now)) ?? now
        return start...now
    }

    private var lastMonthSummary: NutritionSummary {
        NutritionSummary.forTrips(trips, in: lastMonthRange)
    }

    private var yearToDateSummary: NutritionSummary {
        NutritionSummary.forTrips(trips, in: yearToDateRange)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if trips.isEmpty {
                        ContentUnavailableView(
                            "No Data Yet",
                            systemImage: "chart.bar.doc.horizontal",
                            description: Text("Add grocery trips with linked foods to see your nutrition analysis and compare against daily targets")
                        )
                        .padding(.top, 100)
                    } else if lastMonthSummary.totalCalories == 0 && yearToDateSummary.totalCalories == 0 {
                        ContentUnavailableView(
                            "No Nutrition Data",
                            systemImage: "fork.knife.circle",
                            description: Text("Link your purchased items to foods in the Food Bank to track nutrition")
                        )
                        .padding(.top, 100)
                    } else {
                        // Summary header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your daily nutrition averages compared to your family's targets")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Set targets in Settings > Family Goals")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)

                        DailyAverageCard(title: "Last 30 Days", summary: lastMonthSummary, target: settings.dailyNutritionTarget)
                        DailyAverageCard(title: "Year to Date", summary: yearToDateSummary, target: settings.dailyNutritionTarget)

                        // Legend
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Legend").font(.caption).fontWeight(.semibold)
                            HStack(spacing: 16) {
                                LegendItem(color: .themeSuccess, text: "On target")
                                LegendItem(color: .themeWarning, text: "Below target")
                                LegendItem(color: .themeInfo, text: "Above target")
                                LegendItem(color: .themeError, text: "Over limit")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis")
        }
    }
}

// MARK: - Daily Average Card

private struct DailyAverageCard: View {
    let title: String
    let summary: NutritionSummary
    let target: NutritionTarget

    private var daily: NutritionSummary { summary.dailyAverage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text("\(summary.dayCount) days").font(.caption).foregroundStyle(.secondary)
            }

            Text("Daily Average").font(.subheadline).foregroundStyle(.secondary)

            Divider()

            VStack(spacing: 10) {
                NutrientRow(label: "Calories", value: daily.totalCalories, target: target.calories, unit: "kcal", color: .nutritionCalories)
                NutrientRow(label: "Protein", value: daily.totalProtein, target: target.protein, unit: "g", color: .nutritionProtein)
                NutrientRow(label: "Carbs", value: daily.totalCarbohydrates, target: target.carbohydrates, unit: "g", color: .nutritionCarbs)
                NutrientRow(label: "Fat", value: daily.totalFat, target: target.fat, unit: "g", color: .nutritionFat)
                NutrientRow(label: "Sugar", value: daily.totalSugar, target: target.sugar, unit: "g", color: .nutritionSugar, isLimitType: true)
                NutrientRow(label: "Fiber", value: daily.totalFiber, target: target.fiber, unit: "g", color: .nutritionFiber)
                NutrientRow(label: "Sodium", value: daily.totalSodium, target: target.sodium, unit: "mg", color: .nutritionSodium, isLimitType: true)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Nutrient Row with Target Comparison

private struct NutrientRow: View {
    let label: String
    let value: Double
    let target: Double
    let unit: String
    var color: Color = .themePrimary
    var isLimitType: Bool = false  // For sugar/sodium, lower is better

    private var percentage: Double {
        guard target > 0 else { return 0 }
        return (value / target) * 100
    }

    private var progressColor: Color {
        if isLimitType {
            return percentage <= 100 ? .themeSuccess : .themeError
        } else {
            if percentage < 70 { return .themeWarning }
            if percentage <= 130 { return .themeSuccess }
            return .themeInfo
        }
    }

    private var statusIcon: String {
        if isLimitType {
            return percentage <= 100 ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        } else {
            if percentage < 70 { return "arrow.down.circle.fill" }
            if percentage <= 130 { return "checkmark.circle.fill" }
            return "arrow.up.circle.fill"
        }
    }

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(label)
            }
            .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(progressColor)
                        .frame(width: min(geo.size.width, geo.size.width * CGFloat(percentage) / 100))
                }
            }
            .frame(height: 8)

            HStack(spacing: 4) {
                Text("\(Int(value))").fontWeight(.medium).frame(width: 45, alignment: .trailing)
                Text("/\(Int(target))").foregroundStyle(.secondary).frame(width: 45, alignment: .leading)
                Image(systemName: statusIcon).foregroundStyle(progressColor).font(.caption)
            }
            .font(.caption)
        }
    }
}

// MARK: - Legend Item

private struct LegendItem: View {
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }
}
