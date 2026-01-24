import SwiftUI
import SwiftData

struct AnalysisView: View {
    @Query(sort: \GroceryTrip.date) private var trips: [GroceryTrip]

    private var allTimeSummary: NutritionSummary {
        NutritionSummary.forTrips(trips)
    }

    private var last7DaysTrips: [GroceryTrip] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return trips.filter { $0.date >= cutoff }
    }

    private var last7DaysSummary: NutritionSummary {
        NutritionSummary.forTrips(last7DaysTrips)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if trips.isEmpty {
                        ContentUnavailableView(
                            "No Data Yet",
                            systemImage: "chart.bar.doc.horizontal",
                            description: Text("Add grocery trips to see nutrition analysis")
                        )
                        .padding(.top, 100)
                    } else {
                        SummaryCard(title: "Last 7 Days", summary: last7DaysSummary, tripCount: last7DaysTrips.count)
                        SummaryCard(title: "All Time", summary: allTimeSummary, tripCount: trips.count)
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis")
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let summary: NutritionSummary
    let tripCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(tripCount) trip\(tripCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                StatItem(label: "Calories", value: "\(Int(summary.totalCalories))", unit: "kcal")
                Spacer()
                StatItem(label: "Protein", value: String(format: "%.0f", summary.totalProtein), unit: "g")
                Spacer()
                StatItem(label: "Carbs", value: String(format: "%.0f", summary.totalCarbohydrates), unit: "g")
                Spacer()
                StatItem(label: "Fat", value: String(format: "%.0f", summary.totalFat), unit: "g")
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Health Markers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    MiniStat(label: "Sat. Fat", value: summary.totalSaturatedFat, unit: "g")
                    MiniStat(label: "Sugar", value: summary.totalSugar, unit: "g")
                    MiniStat(label: "Fiber", value: summary.totalFiber, unit: "g")
                    MiniStat(label: "Sodium", value: summary.totalSodium, unit: "mg")
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct StatItem: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
            Text("\(label) (\(unit))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MiniStat: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.0f", value))
                .font(.subheadline)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
