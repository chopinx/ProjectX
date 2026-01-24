# ProjectX MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a manual-first MVP that lets a household maintain a local Food Bank, record grocery trips with items linked to foods, and see nutrition summaries over time. Scan and Settings screens are stubbed for future LLM integration.

**Architecture:** Single iOS 17+ SwiftUI app using SwiftData for local persistence. Core domain modeled with `@Model` types (`Food`, `GroceryTrip`, `PurchasedItem`) and plain Swift enums/value types. A `TabView`-based UI surfaces Home (trips), Scan (stub), Food Bank, Analysis, and Settings (stub).

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, XCTest, Xcode 15+, iOS 17 simulator.

---

## Alignment with PRD

- **Grams only:** All quantities stored in grams (PRD requirement). No unit enum.
- **Nutrition per 100g:** All nutrition values are per 100g, scaled by `quantity / 100`.
- **No LLM in MVP:** Scan flow is a stub. Settings shows API key fields but they're not used yet.
- **Simplified Analysis:** MVP shows all-time and last-7-days summaries instead of full charts.

---

## Task 1: Domain Models & Nutrition Summary Logic

**Files:**
- Create: `ProjectX/Models/Food.swift`
- Create: `ProjectX/Models/GroceryTrip.swift`
- Create: `ProjectX/Models/NutritionSummary.swift`
- Modify: `ProjectX/Models/NutritionInfo.swift` (already exists)
- Modify: `ProjectX/Models/FoodCategory.swift` (already exists)
- Test: `ProjectXTests/Domain/NutritionSummaryTests.swift` (already exists, needs fixes)

### Step 1: Update NutritionSummaryTests

Fix tests to match PRD's grams-only model. Replace content of `ProjectXTests/Domain/NutritionSummaryTests.swift`:

```swift
import XCTest
@testable import ProjectX

final class NutritionSummaryTests: XCTestCase {
    func testSummaryForSingleTripSingleItem() {
        // Given a food with nutrition per 100g
        let nutrition = NutritionInfo(
            calories: 350, protein: 12, carbohydrates: 70, fat: 2,
            saturatedFat: 0.5, sugar: 2, fiber: 3, sodium: 5
        )
        let pasta = Food(name: "Pasta", category: .pantry, nutrition: nutrition)

        // And a trip with 500g of that food
        let trip = GroceryTrip(date: Date(), storeName: "Test Store")
        let item = PurchasedItem(name: "Pasta", quantity: 500, price: 2.99, food: pasta)
        trip.items.append(item)

        // When we compute a summary
        let summary = NutritionSummary.forTrips([trip])

        // Then values scale by quantity (500g = 5x 100g)
        XCTAssertEqual(summary.totalCalories, 350 * 5, accuracy: 0.001)
        XCTAssertEqual(summary.totalProtein, 12 * 5, accuracy: 0.001)
        XCTAssertEqual(summary.totalCarbohydrates, 70 * 5, accuracy: 0.001)
        XCTAssertEqual(summary.totalFat, 2 * 5, accuracy: 0.001)
    }

    func testSummaryForMultipleTripsAndItems() {
        let appleNutrition = NutritionInfo(
            calories: 52, protein: 0.3, carbohydrates: 14, fat: 0.2,
            saturatedFat: 0.0, sugar: 10, fiber: 2.4, sodium: 1
        )
        let apple = Food(name: "Apple", category: .produce, nutrition: appleNutrition)

        let milkNutrition = NutritionInfo(
            calories: 64, protein: 3.4, carbohydrates: 4.8, fat: 3.7,
            saturatedFat: 2.4, sugar: 4.8, fiber: 0, sodium: 44
        )
        let milk = Food(name: "Milk", category: .dairy, nutrition: milkNutrition)

        // Trip 1: 450g apples + 1000g milk
        let trip1 = GroceryTrip(date: Date(), storeName: "Store A")
        trip1.items.append(PurchasedItem(name: "Apples", quantity: 450, price: 3.0, food: apple))
        trip1.items.append(PurchasedItem(name: "Milk 1L", quantity: 1000, price: 1.2, food: milk))

        // Trip 2: 300g apples
        let trip2 = GroceryTrip(date: Date(), storeName: "Store B")
        trip2.items.append(PurchasedItem(name: "Apples", quantity: 300, price: 2.0, food: apple))

        let summary = NutritionSummary.forTrips([trip1, trip2])

        // Verify totals are computed
        XCTAssertGreaterThan(summary.totalCalories, 0)
        XCTAssertGreaterThan(summary.totalProtein, 0)
        XCTAssertGreaterThan(summary.totalCarbohydrates, 0)
        XCTAssertGreaterThan(summary.totalFat, 0)
    }

    func testSummaryExcludesItemsWithoutFood() {
        let trip = GroceryTrip(date: Date(), storeName: "Test")
        trip.items.append(PurchasedItem(name: "Unknown Item", quantity: 500, price: 5.0, food: nil))

        let summary = NutritionSummary.forTrips([trip])

        XCTAssertEqual(summary.totalCalories, 0)
    }
}
```

### Step 2: Run tests to verify they fail

```bash
xcodebuild test -project ProjectX.xcodeproj -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: Tests fail (models don't exist yet).

### Step 3: Create Food model

Create `ProjectX/Models/Food.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Food {
    var name: String
    var categoryRaw: String
    @Relationship(deleteRule: .cascade) var nutrition: NutritionInfo?
    var isUserCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        name: String,
        category: FoodCategory = .other,
        nutrition: NutritionInfo? = nil,
        isUserCreated: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.nutrition = nutrition
        self.isUserCreated = isUserCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

### Step 4: Create GroceryTrip and PurchasedItem models

Create `ProjectX/Models/GroceryTrip.swift`:

```swift
import Foundation
import SwiftData

@Model
final class GroceryTrip {
    var date: Date
    var storeName: String?
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PurchasedItem.trip)
    var items: [PurchasedItem] = []

    var totalSpent: Double {
        items.reduce(0) { $0 + $1.price }
    }

    init(
        date: Date = .now,
        storeName: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.date = date
        self.storeName = storeName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PurchasedItem {
    var name: String
    var quantity: Double  // Always in grams (PRD requirement)
    var price: Double
    var food: Food?
    var trip: GroceryTrip?
    var isSkipped: Bool

    /// Calculate nutrition for this item based on quantity in grams
    var calculatedNutrition: NutritionInfo? {
        food?.nutrition?.scaled(byGrams: quantity)
    }

    init(
        name: String,
        quantity: Double,  // grams
        price: Double,
        food: Food? = nil,
        isSkipped: Bool = false
    ) {
        self.name = name
        self.quantity = quantity
        self.price = price
        self.food = food
        self.isSkipped = isSkipped
    }
}
```

### Step 5: Create NutritionSummary

Create `ProjectX/Models/NutritionSummary.swift`:

```swift
import Foundation

struct NutritionSummary {
    var totalCalories: Double
    var totalProtein: Double
    var totalCarbohydrates: Double
    var totalFat: Double
    var totalSaturatedFat: Double
    var totalSugar: Double
    var totalFiber: Double
    var totalSodium: Double

    static var zero: NutritionSummary {
        NutritionSummary(
            totalCalories: 0, totalProtein: 0, totalCarbohydrates: 0,
            totalFat: 0, totalSaturatedFat: 0, totalSugar: 0,
            totalFiber: 0, totalSodium: 0
        )
    }

    static func forTrips(_ trips: [GroceryTrip]) -> NutritionSummary {
        var summary = NutritionSummary.zero

        for trip in trips {
            for item in trip.items where !item.isSkipped {
                guard let nutrition = item.calculatedNutrition else { continue }
                summary.totalCalories += nutrition.calories
                summary.totalProtein += nutrition.protein
                summary.totalCarbohydrates += nutrition.carbohydrates
                summary.totalFat += nutrition.fat
                summary.totalSaturatedFat += nutrition.saturatedFat
                summary.totalSugar += nutrition.sugar
                summary.totalFiber += nutrition.fiber
                summary.totalSodium += nutrition.sodium
            }
        }

        return summary
    }
}
```

### Step 6: Run tests to verify they pass

```bash
xcodebuild test -project ProjectX.xcodeproj -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Step 7: Commit

```bash
git add ProjectX/Models ProjectXTests
git commit -m "feat: add domain models with grams-only quantity storage"
```

---

## Task 2: Configure SwiftData & App Entry

**Files:**
- Modify: `ProjectX/ProjectXApp.swift`

### Step 1: Update ProjectXApp with model container

Replace content of `ProjectX/ProjectXApp.swift`:

```swift
import SwiftUI
import SwiftData

@main
struct ProjectXApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Food.self,
            NutritionInfo.self,
            GroceryTrip.self,
            PurchasedItem.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

### Step 2: Commit

```bash
git add ProjectX/ProjectXApp.swift
git commit -m "feat: configure SwiftData model container"
```

---

## Task 3: Food Bank UI

**Files:**
- Create: `ProjectX/Views/FoodBank/FoodBankView.swift`
- Create: `ProjectX/Views/FoodBank/FoodDetailView.swift`

### Step 1: Create FoodBankView

Create `ProjectX/Views/FoodBank/FoodBankView.swift`:

```swift
import SwiftUI
import SwiftData

struct FoodBankView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory?
    @State private var showingAddFood = false

    var filteredFoods: [Food] {
        var result = foods
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List {
                if foods.isEmpty {
                    ContentUnavailableView(
                        "No Foods Yet",
                        systemImage: "fork.knife",
                        description: Text("Tap + to add your first food item")
                    )
                } else {
                    ForEach(filteredFoods) { food in
                        NavigationLink {
                            FoodDetailView(food: food)
                        } label: {
                            HStack {
                                Image(systemName: food.category.icon)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30)
                                VStack(alignment: .leading) {
                                    Text(food.name)
                                        .font(.headline)
                                    if let nutrition = food.nutrition {
                                        Text("\(Int(nutrition.calories)) kcal per 100g")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteFoods)
                }
            }
            .searchable(text: $searchText, prompt: "Search foods")
            .navigationTitle("Food Bank")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All Categories") { selectedCategory = nil }
                        Divider()
                        ForEach(FoodCategory.allCases) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Label(category.displayName, systemImage: category.icon)
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: selectedCategory == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddFood = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFood) {
                NavigationStack {
                    FoodDetailView(food: nil)
                }
            }
        }
    }

    private func deleteFoods(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredFoods[index])
        }
        try? context.save()
    }
}
```

### Step 2: Create FoodDetailView

Create `ProjectX/Views/FoodBank/FoodDetailView.swift`:

```swift
import SwiftUI
import SwiftData

struct FoodDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String
    @State private var category: FoodCategory
    @State private var calories: String
    @State private var protein: String
    @State private var carbohydrates: String
    @State private var fat: String
    @State private var saturatedFat: String
    @State private var sugar: String
    @State private var fiber: String
    @State private var sodium: String

    private var existingFood: Food?

    init(food: Food?) {
        self.existingFood = food
        _name = State(initialValue: food?.name ?? "")
        _category = State(initialValue: food?.category ?? .other)
        _calories = State(initialValue: Self.format(food?.nutrition?.calories))
        _protein = State(initialValue: Self.format(food?.nutrition?.protein))
        _carbohydrates = State(initialValue: Self.format(food?.nutrition?.carbohydrates))
        _fat = State(initialValue: Self.format(food?.nutrition?.fat))
        _saturatedFat = State(initialValue: Self.format(food?.nutrition?.saturatedFat))
        _sugar = State(initialValue: Self.format(food?.nutrition?.sugar))
        _fiber = State(initialValue: Self.format(food?.nutrition?.fiber))
        _sodium = State(initialValue: Self.format(food?.nutrition?.sodium))
    }

    var body: some View {
        Form {
            Section("Basic Info") {
                TextField("Name", text: $name)
                Picker("Category", selection: $category) {
                    ForEach(FoodCategory.allCases) { cat in
                        Label(cat.displayName, systemImage: cat.icon).tag(cat)
                    }
                }
            }

            Section("Nutrition per 100g") {
                NutritionField(label: "Calories", value: $calories, unit: "kcal")
                NutritionField(label: "Protein", value: $protein, unit: "g")
                NutritionField(label: "Carbohydrates", value: $carbohydrates, unit: "g")
                NutritionField(label: "Fat", value: $fat, unit: "g")
                NutritionField(label: "Saturated Fat", value: $saturatedFat, unit: "g")
                NutritionField(label: "Sugar", value: $sugar, unit: "g")
                NutritionField(label: "Fiber", value: $fiber, unit: "g")
                NutritionField(label: "Sodium", value: $sodium, unit: "mg")
            }
        }
        .navigationTitle(existingFood == nil ? "New Food" : "Edit Food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func save() {
        let nutrition = NutritionInfo(
            calories: Double(calories) ?? 0,
            protein: Double(protein) ?? 0,
            carbohydrates: Double(carbohydrates) ?? 0,
            fat: Double(fat) ?? 0,
            saturatedFat: Double(saturatedFat) ?? 0,
            sugar: Double(sugar) ?? 0,
            fiber: Double(fiber) ?? 0,
            sodium: Double(sodium) ?? 0
        )

        if let food = existingFood {
            food.name = name
            food.category = category
            food.nutrition = nutrition
            food.updatedAt = .now
        } else {
            let food = Food(name: name, category: category, nutrition: nutrition)
            context.insert(food)
        }

        try? context.save()
        dismiss()
    }

    private static func format(_ value: Double?) -> String {
        guard let value, value != 0 else { return "" }
        return String(format: "%.1f", value)
    }
}

private struct NutritionField: View {
    let label: String
    @Binding var value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .leading)
        }
    }
}
```

### Step 3: Commit

```bash
git add ProjectX/Views/FoodBank
git commit -m "feat: add Food Bank UI with add/edit/delete"
```

---

## Task 4: Grocery Trip Management (Home Tab)

**Files:**
- Create: `ProjectX/Views/Home/HomeView.swift`
- Create: `ProjectX/Views/Home/TripDetailView.swift`
- Create: `ProjectX/Views/Home/ItemEditView.swift`

### Step 1: Create HomeView

Create `ProjectX/Views/Home/HomeView.swift`:

```swift
import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \GroceryTrip.date, order: .reverse) private var trips: [GroceryTrip]

    @State private var showingNewTrip = false

    var body: some View {
        NavigationStack {
            List {
                if trips.isEmpty {
                    ContentUnavailableView(
                        "No Trips Yet",
                        systemImage: "cart.badge.plus",
                        description: Text("Tap + to add your first grocery trip")
                    )
                } else {
                    ForEach(trips) { trip in
                        NavigationLink {
                            TripDetailView(trip: trip)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tripTitle(for: trip))
                                    .font(.headline)
                                HStack {
                                    Text("\(trip.items.count) item\(trip.items.count == 1 ? "" : "s")")
                                    Spacer()
                                    Text(String(format: "%.2f", trip.totalSpent))
                                        .fontWeight(.medium)
                                }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteTrips)
                }
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingNewTrip = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTrip) {
                NavigationStack {
                    TripDetailView(trip: nil)
                }
            }
        }
    }

    private func tripTitle(for trip: GroceryTrip) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: trip.date)
        if let store = trip.storeName, !store.isEmpty {
            return "\(store) - \(dateStr)"
        }
        return dateStr
    }

    private func deleteTrips(at offsets: IndexSet) {
        for index in offsets {
            context.delete(trips[index])
        }
        try? context.save()
    }
}
```

### Step 2: Create TripDetailView

Create `ProjectX/Views/Home/TripDetailView.swift`:

```swift
import SwiftUI
import SwiftData

struct TripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Food.name) private var foods: [Food]

    @State private var date: Date
    @State private var storeName: String
    @State private var items: [PurchasedItem]
    @State private var editingItem: PurchasedItem?
    @State private var showingAddItem = false

    private var existingTrip: GroceryTrip?
    private var isNewTrip: Bool { existingTrip == nil }

    init(trip: GroceryTrip?) {
        self.existingTrip = trip
        _date = State(initialValue: trip?.date ?? .now)
        _storeName = State(initialValue: trip?.storeName ?? "")
        _items = State(initialValue: trip?.items ?? [])
    }

    var body: some View {
        Form {
            Section("Trip Info") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Store (optional)", text: $storeName)
            }

            Section {
                if items.isEmpty {
                    Text("No items yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(items) { item in
                        Button {
                            editingItem = item
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundStyle(item.isSkipped ? .secondary : .primary)
                                        .strikethrough(item.isSkipped)
                                    if let food = item.food {
                                        Text(food.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int(item.quantity))g")
                                    Text(String(format: "%.2f", item.price))
                                        .foregroundStyle(.secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteItems)
                }

                Button {
                    showingAddItem = true
                } label: {
                    Label("Add Item", systemImage: "plus.circle")
                }
            } header: {
                Text("Items")
            }
        }
        .navigationTitle(isNewTrip ? "New Trip" : "Edit Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: save)
            }
        }
        .sheet(item: $editingItem) { item in
            NavigationStack {
                ItemEditView(item: item, foods: foods) { updatedItem in
                    if let index = items.firstIndex(where: { $0.id == item.id }) {
                        items[index] = updatedItem
                    }
                    editingItem = nil
                }
            }
        }
        .sheet(isPresented: $showingAddItem) {
            NavigationStack {
                ItemEditView(item: nil, foods: foods) { newItem in
                    items.append(newItem)
                    showingAddItem = false
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    private func save() {
        let trip: GroceryTrip
        if let existingTrip {
            trip = existingTrip
            trip.date = date
            trip.storeName = storeName.isEmpty ? nil : storeName
            trip.updatedAt = .now
            // Clear and re-add items
            trip.items.removeAll()
        } else {
            trip = GroceryTrip(date: date, storeName: storeName.isEmpty ? nil : storeName)
            context.insert(trip)
        }

        for item in items {
            item.trip = trip
            trip.items.append(item)
        }

        try? context.save()
        dismiss()
    }
}
```

### Step 3: Create ItemEditView

Create `ProjectX/Views/Home/ItemEditView.swift`:

```swift
import SwiftUI
import SwiftData

struct ItemEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var quantity: String
    @State private var price: String
    @State private var selectedFood: Food?
    @State private var isSkipped: Bool

    private let existingItem: PurchasedItem?
    private let foods: [Food]
    private let onSave: (PurchasedItem) -> Void

    init(item: PurchasedItem?, foods: [Food], onSave: @escaping (PurchasedItem) -> Void) {
        self.existingItem = item
        self.foods = foods
        self.onSave = onSave
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item != nil ? String(format: "%.0f", item!.quantity) : "")
        _price = State(initialValue: item != nil ? String(format: "%.2f", item!.price) : "")
        _selectedFood = State(initialValue: item?.food)
        _isSkipped = State(initialValue: item?.isSkipped ?? false)
    }

    var body: some View {
        Form {
            Section("Item Details") {
                TextField("Name", text: $name)
                HStack {
                    TextField("Quantity", text: $quantity)
                        .keyboardType(.numberPad)
                    Text("g")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                }
            }

            Section("Link to Food") {
                Picker("Food", selection: $selectedFood) {
                    Text("None").tag(nil as Food?)
                    ForEach(foods) { food in
                        Text(food.name).tag(food as Food?)
                    }
                }

                if let food = selectedFood, let nutrition = food.nutrition {
                    let qty = Double(quantity) ?? 0
                    let scaled = nutrition.scaled(byGrams: qty)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Estimated nutrition for \(Int(qty))g:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(scaled.calories)) kcal, \(Int(scaled.protein))g protein")
                            .font(.caption)
                    }
                }
            }

            Section {
                Toggle("Skip this item", isOn: $isSkipped)
            } footer: {
                Text("Skipped items won't count toward nutrition totals")
            }
        }
        .navigationTitle(existingItem == nil ? "Add Item" : "Edit Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    let item = existingItem ?? PurchasedItem(
                        name: name,
                        quantity: Double(quantity) ?? 0,
                        price: Double(price) ?? 0
                    )
                    item.name = name
                    item.quantity = Double(quantity) ?? 0
                    item.price = Double(price) ?? 0
                    item.food = selectedFood
                    item.isSkipped = isSkipped
                    onSave(item)
                }
                .disabled(name.isEmpty || quantity.isEmpty)
            }
        }
    }
}
```

### Step 4: Commit

```bash
git add ProjectX/Views/Home
git commit -m "feat: add Home tab with trip management"
```

---

## Task 5: Analysis Tab

**Files:**
- Create: `ProjectX/Views/Analysis/AnalysisView.swift`

### Step 1: Create AnalysisView

Create `ProjectX/Views/Analysis/AnalysisView.swift`:

```swift
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
```

### Step 2: Commit

```bash
git add ProjectX/Views/Analysis
git commit -m "feat: add Analysis tab with nutrition summaries"
```

---

## Task 6: Scan & Settings Stubs

**Files:**
- Create: `ProjectX/Views/Scan/ScanView.swift`
- Create: `ProjectX/Views/Settings/SettingsView.swift`

### Step 1: Create ScanView stub

Create `ProjectX/Views/Scan/ScanView.swift`:

```swift
import SwiftUI

struct ScanView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundStyle(.tertiary)

                VStack(spacing: 8) {
                    Text("Receipt Scanning")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Coming Soon")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                Text("In a future version, you'll be able to photograph grocery receipts and have AI extract all items automatically.\n\nFor now, add trips manually from the Home tab.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Scan")
        }
    }
}
```

### Step 2: Create SettingsView stub

Create `ProjectX/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI

enum LLMProvider: String, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    var id: String { rawValue }
}

struct SettingsView: View {
    @AppStorage("llmProvider") private var providerRaw: String = LLMProvider.openAI.rawValue
    @AppStorage("apiKey") private var apiKey: String = ""

    private var provider: LLMProvider {
        LLMProvider(rawValue: providerRaw) ?? .openAI
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Provider", selection: $providerRaw) {
                        ForEach(LLMProvider.allCases) { p in
                            Text(p.rawValue).tag(p.rawValue)
                        }
                    }
                } header: {
                    Text("LLM Provider")
                } footer: {
                    Text("Select the AI service to use for receipt scanning (coming soon)")
                }

                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                } header: {
                    Text("API Key")
                } footer: {
                    Text("Your API key is stored locally on this device. LLM features are not yet active in this version.")
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0 (MVP)")
                }
            }
            .navigationTitle("Settings")
        }
    }
}
```

### Step 3: Commit

```bash
git add ProjectX/Views/Scan ProjectX/Views/Settings
git commit -m "feat: add Scan and Settings stub views"
```

---

## Task 7: Final Integration & QA

### Step 1: Build and test

```bash
xcodebuild build -project ProjectX.xcodeproj -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project ProjectX.xcodeproj -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 16'
```

### Step 2: Manual QA checklist

- [ ] Food Bank: Add, edit, delete foods with nutrition data
- [ ] Home: Create trips, add items, link to foods
- [ ] Home: Edit and delete trips
- [ ] Analysis: Verify summaries update with trip data
- [ ] Scan: Shows "Coming Soon" message
- [ ] Settings: Provider picker and API key field work (stored locally)
- [ ] App persists data across launches

### Step 3: Final commit

```bash
git add .
git commit -m "feat: complete MVP implementation"
```

---

## Summary

**MVP Features:**
1. SwiftData models: Food, NutritionInfo, GroceryTrip, PurchasedItem
2. All quantities in grams (PRD compliant)
3. Food Bank with CRUD operations
4. Grocery trip management with item linking
5. Nutrition analysis (all-time + last 7 days)
6. Stub screens for Scan and Settings

**Files:** ~15 Swift files

**Post-MVP (when adding LLM):**
- Implement `LLMService` protocol
- Add `OpenAIService` and `ClaudeService`
- Add `KeychainHelper` for secure API key storage
- Update `ScanView` with camera/photo picker
- Add receipt review flow
