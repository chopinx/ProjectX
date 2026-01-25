import SwiftUI
import SwiftData
import Charts

// MARK: - Time Period

enum TimePeriod: String, CaseIterable, Identifiable {
    case week = "7 Days", month = "30 Days", threeMonths = "3 Months"
    case yearToDate = "Year to Date", allTime = "All Time", custom = "Custom"

    var id: String { rawValue }

    func dateRange(customStart: Date? = nil, customEnd: Date? = nil) -> ClosedRange<Date>? {
        let now = Date(), cal = Calendar.current
        switch self {
        case .week: return cal.date(byAdding: .day, value: -7, to: now)!...now
        case .month: return cal.date(byAdding: .month, value: -1, to: now)!...now
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: now)!...now
        case .yearToDate: return cal.date(from: cal.dateComponents([.year], from: now))!...now
        case .allTime: return nil
        case .custom: return customStart.flatMap { s in customEnd.map { s...$0 } }
        }
    }
}

enum CategoryLevel: String, CaseIterable, Identifiable {
    case main = "Main Category", sub = "Subcategory"
    var id: String { rawValue }
}

struct NutritionBreakdown: Identifiable {
    let id = UUID()
    let category: String, color: Color
    let calories, protein, carbohydrates, fat: Double
    let caloriesPercent, proteinPercent, carbsPercent, fatPercent: Double
}

// MARK: - Analysis View

struct AnalysisView: View {
    @Query(sort: \GroceryTrip.date) private var trips: [GroceryTrip]
    @Query private var foods: [Food]
    @State private var settings = AppSettings()
    @AppStorage("excludePantryStaples") private var excludePantryStaples = false
    @AppStorage("selectedTimePeriod") private var selectedPeriodRaw = TimePeriod.month.rawValue
    @AppStorage("categoryLevel") private var categoryLevelRaw = CategoryLevel.main.rawValue
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var customEndDate = Date()
    @State private var showingDatePicker = false

    private var selectedPeriod: TimePeriod { TimePeriod(rawValue: selectedPeriodRaw) ?? .month }
    private var categoryLevel: CategoryLevel { CategoryLevel(rawValue: categoryLevelRaw) ?? .main }
    private var dateRange: ClosedRange<Date>? { selectedPeriod.dateRange(customStart: customStartDate, customEnd: customEndDate) }
    private var summary: NutritionSummary { NutritionSummary.forTrips(trips, in: dateRange, excludePantryStaples: excludePantryStaples) }
    private var nutritionBreakdown: [NutritionBreakdown] { computeBreakdown() }
    private var foodsHash: Int { foods.reduce(into: Hasher()) { $0.combine($1.id); $0.combine($1.isPantryStaple) }.finalize() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 0).id(foodsHash)
                    if trips.isEmpty {
                        emptyState("No Data Yet", icon: "chart.bar.doc.horizontal", text: "Add grocery trips with linked foods to see your nutrition analysis")
                    } else if summary.totalCalories == 0 {
                        emptyState("No Nutrition Data", icon: "fork.knife.circle", text: "Link your purchased items to foods in the Food Bank to track nutrition")
                    } else {
                        filtersSection
                        timePeriodSection
                        DailyAverageCard(summary: summary, target: settings.dailyNutritionTarget, dayCount: summary.dayCount)
                        if !nutritionBreakdown.isEmpty { nutritionSourceSection }
                        legendSection
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis")
            .sheet(isPresented: $showingDatePicker) { customDatePickerSheet }
        }
    }

    private func emptyState(_ title: String, icon: String, text: String) -> some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(text)).padding(.top, 100)
    }

    private var filtersSection: some View {
        Toggle(isOn: $excludePantryStaples) {
            Label { VStack(alignment: .leading, spacing: 2) {
                Text("Exclude Pantry Staples")
                Text("Hide long-lasting items like salt, oil, spices").font(.caption).foregroundStyle(.secondary)
            }} icon: { Image(systemName: "shippingbox") }
        }
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var timePeriodSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Period").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimePeriod.allCases) { period in
                        Button {
                            if period == .custom { showingDatePicker = true }
                            selectedPeriodRaw = period.rawValue
                        } label: {
                            Text(period.rawValue).font(.subheadline)
                                .padding(.horizontal, 14).padding(.vertical, 10)
                                .background(selectedPeriod == period ? Color.themePrimary : Color(.tertiarySystemBackground))
                                .foregroundStyle(selectedPeriod == period ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.pressFeedback)
                    }
                }
            }
            if selectedPeriod == .custom {
                HStack {
                    Text("\(customStartDate.formatted(date: .abbreviated, time: .omitted)) - \(customEndDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Edit") { showingDatePicker = true }.font(.caption)
                }
            }
        }
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var nutritionSourceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nutrition Sources").font(.headline)
                Spacer()
                Picker("Level", selection: $categoryLevelRaw) {
                    ForEach(CategoryLevel.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.pickerStyle(.segmented).frame(width: 200)
            }
            NutritionPieChart(title: "Calories", data: nutritionBreakdown, keyPath: \.caloriesPercent)
            NutritionPieChart(title: "Protein", data: nutritionBreakdown, keyPath: \.proteinPercent)
            NutritionPieChart(title: "Carbs", data: nutritionBreakdown, keyPath: \.carbsPercent)
            NutritionPieChart(title: "Fat", data: nutritionBreakdown, keyPath: \.fatPercent)
        }
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target Legend").font(.caption).fontWeight(.semibold)
            HStack(spacing: 16) {
                LegendItem("On target", .themeSuccess); LegendItem("Below", .themeWarning)
                LegendItem("Above", .themeInfo); LegendItem("Over limit", .themeError)
            }
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var customDatePickerSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Start Date", selection: $customStartDate, displayedComponents: .date)
                DatePicker("End Date", selection: $customEndDate, in: customStartDate..., displayedComponents: .date)
            }
            .navigationTitle("Custom Range").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingDatePicker = false } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showingDatePicker = false } }
            }
        }
        .presentationDetents([.medium])
    }

    private func computeBreakdown() -> [NutritionBreakdown] {
        var totals: [String: (color: Color, cal: Double, pro: Double, carb: Double, fat: Double)] = [:]
        let filteredTrips = dateRange.map { r in trips.filter { r.contains($0.date) } } ?? trips

        for trip in filteredTrips {
            for item in trip.items where !item.isSkipped {
                guard let food = item.food, let n = item.calculatedNutrition else { continue }
                if excludePantryStaples && food.isPantryStaple { continue }
                let key = categoryLevel == .sub ? food.category.displayName : food.category.main.displayName
                var cur = totals[key] ?? (food.category.main.themeColor, 0, 0, 0, 0)
                cur.cal += n.calories; cur.pro += n.protein; cur.carb += n.carbohydrates; cur.fat += n.fat
                totals[key] = cur
            }
        }

        let (tCal, tPro, tCarb, tFat) = totals.values.reduce((0.0, 0.0, 0.0, 0.0)) { ($0.0 + $1.cal, $0.1 + $1.pro, $0.2 + $1.carb, $0.3 + $1.fat) }
        func pct(_ v: Double, _ t: Double) -> Double { t > 0 ? (v / t) * 100 : 0 }

        return totals.map { k, v in
            NutritionBreakdown(category: k, color: v.color, calories: v.cal, protein: v.pro, carbohydrates: v.carb, fat: v.fat,
                               caloriesPercent: pct(v.cal, tCal), proteinPercent: pct(v.pro, tPro), carbsPercent: pct(v.carb, tCarb), fatPercent: pct(v.fat, tFat))
        }.sorted { $0.calories > $1.calories }
    }
}

// MARK: - Supporting Views

private struct LegendItem: View {
    let text: String, color: Color
    init(_ text: String, _ color: Color) { self.text = text; self.color = color }
    var body: some View { HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(text) } }
}

private struct NutritionPieChart: View {
    let title: String, data: [NutritionBreakdown], keyPath: KeyPath<NutritionBreakdown, Double>
    private var sorted: [NutritionBreakdown] { data.sorted { $0[keyPath: keyPath] > $1[keyPath: keyPath] } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).fontWeight(.medium)
            HStack(spacing: 16) {
                Chart(sorted) { SectorMark(angle: .value("Value", $0[keyPath: keyPath]), innerRadius: .ratio(0.5), angularInset: 1).foregroundStyle($0.color).cornerRadius(4) }
                    .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sorted.prefix(5)) { item in
                        HStack(spacing: 6) {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                            Text(item.category).font(.caption).lineLimit(1)
                            Spacer()
                            Text("\(Int(item[keyPath: keyPath]))%").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if sorted.count > 5 { Text("+\(sorted.count - 5) more").font(.caption2).foregroundStyle(.tertiary) }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DailyAverageCard: View {
    let summary: NutritionSummary, target: NutritionTarget, dayCount: Int
    private var daily: NutritionSummary { summary.dailyAverage }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Text("Daily Average").font(.headline); Spacer(); Text("\(dayCount) days").font(.caption).foregroundStyle(.secondary) }
            Divider()
            VStack(spacing: 10) {
                NutrientRow("Calories", daily.totalCalories, target.calories, "kcal", .nutritionCalories)
                NutrientRow("Protein", daily.totalProtein, target.protein, "g", .nutritionProtein)
                NutrientRow("Carbs", daily.totalCarbohydrates, target.carbohydrates, "g", .nutritionCarbs)
                NutrientRow("Fat", daily.totalFat, target.fat, "g", .nutritionFat)
                NutrientRow("Sugar", daily.totalSugar, target.sugar, "g", .nutritionSugar, isLimit: true)
                NutrientRow("Fiber", daily.totalFiber, target.fiber, "g", .nutritionFiber)
                NutrientRow("Sodium", daily.totalSodium, target.sodium, "mg", .nutritionSodium, isLimit: true)
            }
        }
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct NutrientRow: View {
    let label: String, value: Double, target: Double, unit: String, color: Color, isLimit: Bool

    init(_ label: String, _ value: Double, _ target: Double, _ unit: String, _ color: Color, isLimit: Bool = false) {
        self.label = label; self.value = value; self.target = target; self.unit = unit; self.color = color; self.isLimit = isLimit
    }

    private var pct: Double { target > 0 ? (value / target) * 100 : 0 }
    private var progressColor: Color { isLimit ? (pct <= 100 ? .themeSuccess : .themeError) : (pct < 70 ? .themeWarning : pct <= 130 ? .themeSuccess : .themeInfo) }
    private var icon: String { isLimit ? (pct <= 100 ? "checkmark.circle.fill" : "exclamationmark.circle.fill") : (pct < 70 ? "arrow.down.circle.fill" : pct <= 130 ? "checkmark.circle.fill" : "arrow.up.circle.fill") }

    var body: some View {
        HStack {
            HStack(spacing: 4) { Circle().fill(color).frame(width: 8, height: 8); Text(label) }.frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4).fill(progressColor).frame(width: min(geo.size.width, geo.size.width * pct / 100))
                }
            }.frame(height: 8)
            HStack(spacing: 4) {
                Text("\(Int(value))").fontWeight(.medium).frame(width: 45, alignment: .trailing)
                Text("/\(Int(target))").foregroundStyle(.secondary).frame(width: 45, alignment: .leading)
                Image(systemName: icon).foregroundStyle(progressColor).font(.caption)
            }.font(.caption)
        }
    }
}
