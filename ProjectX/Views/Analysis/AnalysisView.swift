import SwiftUI
import SwiftData
import Charts

// MARK: - Time Period

enum TimePeriod: String, CaseIterable, Identifiable {
    case today = "Today", week = "7 Days", month = "30 Days", threeMonths = "3 Months"
    case yearToDate = "Year to Date", allTime = "All Time", custom = "Custom"

    var id: String { rawValue }

    func dateRange(customStart: Date? = nil, customEnd: Date? = nil) -> ClosedRange<Date>? {
        let now = Date(), cal = Calendar.current
        switch self {
        case .today:
            let startOfDay = cal.startOfDay(for: now)
            return startOfDay...now
        case .week: return cal.date(byAdding: .day, value: -7, to: now)!...now
        case .month: return cal.date(byAdding: .month, value: -1, to: now)!...now
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: now)!...now
        case .yearToDate: return cal.date(from: cal.dateComponents([.year], from: now))!...now
        case .allTime: return nil
        case .custom:
            guard let start = customStart, let end = customEnd else { return nil }
            return start...end
        }
    }
}

enum CategoryLevel: String, CaseIterable, Identifiable {
    case main = "Main Category", sub = "Subcategory"
    var id: String { rawValue }
}

enum DataSource: String, CaseIterable, Identifiable {
    case all = "All"
    case trips = "Trips"
    case meals = "Meals"
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
    @Query(sort: \GroceryTrip.date) private var allTrips: [GroceryTrip]
    @Query(sort: \Meal.date) private var allMeals: [Meal]
    @Query private var foods: [Food]
    @Bindable var settings: AppSettings

    private var trips: [GroceryTrip] {
        guard let profileId = settings.activeProfileId else { return allTrips }
        return allTrips.filter { $0.profile?.id == profileId }
    }

    private var meals: [Meal] {
        guard let profileId = settings.activeProfileId else { return allMeals }
        return allMeals.filter { $0.profile?.id == profileId }
    }

    private var currentNutritionTarget: NutritionTarget {
        if let profileId = settings.activeProfileId {
            return settings.nutritionTarget(for: profileId)
        }
        return settings.dailyNutritionTarget
    }
    @AppStorage("excludePantryStaples") private var excludePantryStaples = false
    @AppStorage("selectedTimePeriod") private var selectedPeriodRaw = TimePeriod.month.rawValue
    @AppStorage("categoryLevel") private var categoryLevelRaw = CategoryLevel.main.rawValue
    @AppStorage("dataSource") private var dataSourceRaw = DataSource.all.rawValue
    @State private var customStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var customEndDate = Date()
    @State private var showingDatePicker = false
    @State private var previousPeriodRaw: String = TimePeriod.month.rawValue

    private var selectedPeriod: TimePeriod { TimePeriod(rawValue: selectedPeriodRaw) ?? .month }
    private var categoryLevel: CategoryLevel { CategoryLevel(rawValue: categoryLevelRaw) ?? .main }
    private var dataSource: DataSource { DataSource(rawValue: dataSourceRaw) ?? .all }
    private var dateRange: ClosedRange<Date>? { selectedPeriod.dateRange(customStart: customStartDate, customEnd: customEndDate) }
    private var summary: NutritionSummary {
        switch dataSource {
        case .all: return NutritionSummary.combined(trips: trips, meals: meals, in: dateRange, excludePantryStaples: excludePantryStaples)
        case .trips: return NutritionSummary.forTrips(trips, in: dateRange, excludePantryStaples: excludePantryStaples)
        case .meals: return NutritionSummary.forMeals(meals, in: dateRange, excludePantryStaples: excludePantryStaples)
        }
    }
    private var nutritionBreakdown: [NutritionBreakdown] { computeBreakdown() }
    private var foodsHash: Int { foods.reduce(into: Hasher()) { $0.combine($1.id); $0.combine($1.isPantryStaple) }.finalize() }
    private var hasData: Bool { !allTrips.isEmpty || !allMeals.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 0).id(foodsHash)
                    // Always show filters so user can adjust them
                    dataSourceSection
                    filtersSection
                    timePeriodSection

                    if !hasData {
                        emptyState("No Data Yet", icon: "chart.bar.doc.horizontal", text: "Add grocery trips or meals with linked foods to see your nutrition analysis")
                    } else if summary.totalCalories == 0 {
                        emptyState("No Nutrition Data", icon: "fork.knife.circle", text: "Link your items to foods in the Food Bank to track nutrition")
                    } else {
                        DailyAverageCard(summary: summary, target: currentNutritionTarget, dayCount: summary.dayCount)
                        if !nutritionBreakdown.isEmpty { nutritionSourceSection }
                        legendSection
                    }
                }
                .padding()
            }
            .navigationTitle("Analysis")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileToolbarButton(settings: settings)
                }
            }
            .sheet(isPresented: $showingDatePicker) { customDatePickerSheet }
        }
    }

    private func emptyState(_ title: String, icon: String, text: String) -> some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(text)).padding(.top, 100)
    }

    private var dataSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Source").font(.headline)
            Picker("Source", selection: $dataSourceRaw) {
                ForEach(DataSource.allCases) { source in
                    Text(source.rawValue).tag(source.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
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
                        FilterChip(period.rawValue, isSelected: selectedPeriod == period) {
                            if period == .custom {
                                previousPeriodRaw = selectedPeriodRaw
                                showingDatePicker = true
                            }
                            selectedPeriodRaw = period.rawValue
                        }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nutrition by Category").font(.headline)
                Spacer()
                Picker("Level", selection: $categoryLevelRaw) {
                    ForEach(CategoryLevel.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }.pickerStyle(.segmented).frame(width: 180)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                NutritionPieChart(title: "Calories", data: nutritionBreakdown, keyPath: \.caloriesPercent)
                NutritionPieChart(title: "Protein", data: nutritionBreakdown, keyPath: \.proteinPercent)
                NutritionPieChart(title: "Carbs", data: nutritionBreakdown, keyPath: \.carbsPercent)
                NutritionPieChart(title: "Fat", data: nutritionBreakdown, keyPath: \.fatPercent)
            }
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
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        selectedPeriodRaw = previousPeriodRaw
                        showingDatePicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { showingDatePicker = false } }
            }
        }
        .presentationDetents([.medium])
    }

    private func computeBreakdown() -> [NutritionBreakdown] {
        var totals: [String: (color: Color, cal: Double, pro: Double, carb: Double, fat: Double)] = [:]

        // Helper to accumulate nutrition from items
        func accumulate(food: Food?, nutrition: NutritionInfo?) {
            guard let food = food, let n = nutrition else { return }
            if excludePantryStaples && food.isPantryStaple { return }
            let key = categoryLevel == .sub ? food.category.displayName : food.category.main.displayName
            var cur = totals[key] ?? (food.category.main.themeColor, 0, 0, 0, 0)
            cur.cal += n.calories; cur.pro += n.protein; cur.carb += n.carbohydrates; cur.fat += n.fat
            totals[key] = cur
        }

        // Include trips if data source is all or trips
        if dataSource == .all || dataSource == .trips {
            let filteredTrips = dateRange.map { r in trips.filter { r.contains($0.date) } } ?? trips
            for trip in filteredTrips {
                for item in trip.items where !item.isSkipped {
                    accumulate(food: item.food, nutrition: item.calculatedNutrition)
                }
            }
        }

        // Include meals if data source is all or meals
        if dataSource == .all || dataSource == .meals {
            let filteredMeals = dateRange.map { r in meals.filter { r.contains($0.date) } } ?? meals
            for meal in filteredMeals {
                for item in meal.items where !item.isSkipped {
                    accumulate(food: item.food, nutrition: item.calculatedNutrition)
                }
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

// MARK: - Helpers

private func statusColor(pct: Double, isLimit: Bool) -> Color {
    isLimit ? (pct <= 100 ? .themeSuccess : .themeError) : (pct < 70 ? .themeWarning : pct <= 130 ? .themeSuccess : .themeInfo)
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
        VStack(spacing: 8) {
            Text(title).font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
            Chart(sorted) { SectorMark(angle: .value("Value", $0[keyPath: keyPath]), innerRadius: .ratio(0.5), angularInset: 1).foregroundStyle($0.color).cornerRadius(3) }
                .frame(width: 80, height: 80)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(sorted.prefix(3)) { item in
                    HStack(spacing: 4) {
                        Circle().fill(item.color).frame(width: 6, height: 6)
                        Text(item.category).font(.caption2).lineLimit(1)
                        Spacer()
                        Text("\(Int(item[keyPath: keyPath]))%").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DailyAverageCard: View {
    let summary: NutritionSummary, target: NutritionTarget, dayCount: Int
    @State private var showMicros = false
    private var d: NutritionSummary { summary.dailyAverage }
    private var t: NutritionTarget { target }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Average").font(.headline)
                Spacer()
                Text("\(dayCount) days").font(.caption).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.themePrimary.opacity(0.15)).clipShape(Capsule())
            }
            VStack(spacing: 8) {
                NutrientRow("Calories", d.totalCalories, t.calories, .nutritionCalories)
                NutrientRow("Protein", d.totalProtein, t.protein, .nutritionProtein)
                NutrientRow("Carbs", d.totalCarbohydrates, t.carbohydrates, .nutritionCarbs)
                NutrientRow("Fat", d.totalFat, t.fat, .nutritionFat)
            }
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fat Details").font(.caption).foregroundStyle(.secondary)
                    CompactNutrient("Saturated", d.totalSaturatedFat, t.saturatedFat, limit: true)
                    CompactNutrient("Omega-3", d.totalOmega3, t.omega3)
                    CompactNutrient("Omega-6", d.totalOmega6, t.omega6)
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Limits").font(.caption).foregroundStyle(.secondary)
                    CompactNutrient("Sugar", d.totalSugar, t.sugar, limit: true)
                    CompactNutrient("Fiber", d.totalFiber, t.fiber)
                    CompactNutrient("Sodium", d.totalSodium, t.sodium, limit: true)
                }
            }
            Divider()
            DisclosureGroup(isExpanded: $showMicros) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    MicroNutrient("Vitamin A", d.totalVitaminA, t.vitaminA, .purple)
                    MicroNutrient("Vitamin C", d.totalVitaminC, t.vitaminC, .orange)
                    MicroNutrient("Vitamin D", d.totalVitaminD, t.vitaminD, .yellow)
                    MicroNutrient("Calcium", d.totalCalcium, t.calcium, .cyan)
                    MicroNutrient("Iron", d.totalIron, t.iron, .red)
                    MicroNutrient("Potassium", d.totalPotassium, t.potassium, .green)
                }.padding(.top, 8)
            } label: {
                HStack {
                    Text("Micronutrients").font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Text(showMicros ? "Hide" : "Show").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding().background(.regularMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CompactNutrient: View {
    let label: String, value: Double, target: Double, limit: Bool
    init(_ label: String, _ value: Double, _ target: Double, limit: Bool = false) {
        self.label = label; self.value = value; self.target = target; self.limit = limit
    }
    private var pct: Double { target > 0 ? (value / target) * 100 : 0 }

    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).lineLimit(1).frame(maxWidth: 60, alignment: .leading)
            Spacer()
            Text("\(Int(value))/\(Int(target))").font(.caption2).fontWeight(.medium).lineLimit(1)
            Circle().fill(statusColor(pct: pct, isLimit: limit)).frame(width: 6, height: 6)
        }
    }
}

private struct MicroNutrient: View {
    let label: String, value: Double, target: Double, color: Color
    init(_ label: String, _ value: Double, _ target: Double, _ color: Color) {
        self.label = label; self.value = value; self.target = target; self.color = color
    }
    private var pct: Double { target > 0 ? min((value / target) * 100, 100) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                Text("\(Int(pct))%").font(.caption2).fontWeight(.medium).foregroundStyle(statusColor(pct: pct, isLimit: false))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 2).fill(color).frame(width: geo.size.width * pct / 100)
                }
            }.frame(height: 4)
            Text("\(Int(value))/\(Int(target))").font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
        }
        .padding(8).background(Color(.tertiarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct NutrientRow: View {
    let label: String, value: Double, target: Double, color: Color
    init(_ label: String, _ value: Double, _ target: Double, _ color: Color) {
        self.label = label; self.value = value; self.target = target; self.color = color
    }
    private var pct: Double { target > 0 ? (value / target) * 100 : 0 }
    private var progColor: Color { statusColor(pct: pct, isLimit: false) }
    private var icon: String { pct < 70 ? "arrow.down.circle.fill" : pct <= 130 ? "checkmark.circle.fill" : "arrow.up.circle.fill" }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(label).font(.subheadline).lineLimit(1)
            }.frame(width: 75, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(color.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4).fill(progColor).frame(width: min(geo.size.width, geo.size.width * pct / 100))
                }
            }.frame(height: 8)
            HStack(spacing: 2) {
                Text("\(Int(value))").fontWeight(.medium).frame(width: 40, alignment: .trailing)
                Text("/\(Int(target))").foregroundStyle(.secondary).frame(width: 40, alignment: .leading)
                Image(systemName: icon).foregroundStyle(progColor)
            }.font(.caption).lineLimit(1)
        }
    }
}
