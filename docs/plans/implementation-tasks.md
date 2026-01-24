# ProjectX Implementation Tasks

> Detailed task breakdown for MVP implementation. See [main PRD](2025-01-24-mvp-projectx.md) for overview.

---

## Task 1: Domain Models & Nutrition Summary Logic

**Files:**
- Create: `ProjectX/Models/Food.swift`
- Create: `ProjectX/Models/GroceryTrip.swift`
- Create: `ProjectX/Models/NutritionSummary.swift`
- Modify: `ProjectX/Models/NutritionInfo.swift` (already exists)
- Modify: `ProjectX/Models/FoodCategory.swift` (already exists)
- Test: `ProjectXTests/Domain/NutritionSummaryTests.swift`

### Step 1: Verify existing models

Ensure `ProjectX/Models/FoodCategory.swift` exists with all categories.
Ensure `ProjectX/Models/NutritionInfo.swift` exists with `scaled(byGrams:)` method.

### Step 2: Create Food model

Create `ProjectX/Models/Food.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Food {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var categoryRaw: String
    @Relationship(deleteRule: .cascade) var nutrition: NutritionInfo?
    @Relationship var tags: [Tag] = []
    var isUserCreated: Bool
    var createdAt: Date
    var updatedAt: Date

    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory = .other,
        nutrition: NutritionInfo? = nil,
        tags: [Tag] = [],
        isUserCreated: Bool = true
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.nutrition = nutrition
        self.tags = tags
        self.isUserCreated = isUserCreated
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

### Step 3: Create GroceryTrip and PurchasedItem models

Create `ProjectX/Models/GroceryTrip.swift`:

```swift
import Foundation
import SwiftData

@Model
final class GroceryTrip {
    @Attribute(.unique) var id: UUID
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
        id: UUID = UUID(),
        date: Date = .now,
        storeName: String? = nil
    ) {
        self.id = id
        self.date = date
        self.storeName = storeName
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class PurchasedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var quantity: Double  // Always in grams (PRD requirement)
    var price: Double
    var food: Food?
    var trip: GroceryTrip?
    var isSkipped: Bool

    var calculatedNutrition: NutritionInfo? {
        food?.nutrition?.scaled(byGrams: quantity)
    }

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        price: Double,
        food: Food? = nil,
        isSkipped: Bool = false
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.price = price
        self.food = food
        self.isSkipped = isSkipped
    }
}
```

### Step 4: Create NutritionSummary

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

---

## Task 2: Keychain Helper & App Settings

**Files:**
- Create: `ProjectX/Utils/KeychainHelper.swift`
- Create: `ProjectX/Services/AppSettings.swift`

### Step 1: Create KeychainHelper

See `ProjectX/Utils/KeychainHelper.swift` for implementation.

### Step 2: Create AppSettings

See `ProjectX/Services/AppSettings.swift` for implementation with:
- LLMProvider enum (OpenAI, Claude)
- Secure API key storage via Keychain
- Provider selection persistence

---

## Task 3: LLM Service Layer

**Files:**
- Create: `ProjectX/Services/LLMService.swift`
- Create: `ProjectX/Services/OpenAIService.swift`
- Create: `ProjectX/Services/ClaudeService.swift`

### Key Components

- `LLMService` protocol with methods for receipt extraction, nutrition label extraction, nutrition estimation
- `ExtractedReceiptItem` and `ExtractedNutrition` response types
- `LLMError` for error handling
- `LLMJSONParser` for response parsing

---

## Task 4: Configure SwiftData & App Entry

**Files:**
- Modify: `ProjectX/ProjectXApp.swift`
- Modify: `ProjectX/ContentView.swift`

Schema includes: Food, NutritionInfo, GroceryTrip, PurchasedItem, Tag, AppSettings

---

## Task 5: Food Bank UI

**Files:**
- Create: `ProjectX/Views/FoodBank/FoodBankView.swift`
- Create: `ProjectX/Views/FoodBank/FoodDetailView.swift`

Features:
- List all foods with search and category filter
- Add/edit foods with category and tag support
- AI nutrition estimation
- Nutrition label scanning

---

## Task 6: Receipt Scanning Flow

**Files:**
- Create: `ProjectX/Views/Scan/ScanView.swift`
- Create: `ProjectX/Views/Scan/ReceiptReviewView.swift`
- Create: `ProjectX/Views/Scan/NewFoodSheet.swift`

Features:
- Camera capture and photo library
- LLM receipt extraction
- Item review with food linking
- New food creation during review

---

## Task 7: Home Tab & Analysis Tab

**Files:**
- Create: `ProjectX/Views/Home/HomeView.swift`
- Create: `ProjectX/Views/Home/TripDetailView.swift`
- Create: `ProjectX/Views/Analysis/AnalysisView.swift`

Features:
- Trip list with delete
- Trip details with nutrition summary
- 7-day and all-time analysis

---

## Task 8: Settings View

**Files:**
- Create: `ProjectX/Views/Settings/SettingsView.swift`

Features:
- LLM provider selection
- API key management with validation
- Data export/import
- Restore default tags

---

## Task 9: Final Integration & QA

Build and test commands:
```bash
xcodebuild build -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Manual QA Checklist

- [ ] Settings: Add API key, verify stored in Keychain
- [ ] Settings: Switch providers, verify key association
- [ ] Scan: Take photo or select image
- [ ] Scan: Verify LLM extracts items with grams and prices
- [ ] Scan: Review items, skip/link/add new foods
- [ ] Scan: Save trip successfully
- [ ] Food Bank: Add food manually
- [ ] Food Bank: Use AI estimate for nutrition
- [ ] Food Bank: Scan nutrition label
- [ ] Food Bank: Edit and delete foods
- [ ] Home: View trips list
- [ ] Home: View trip details with nutrition
- [ ] Home: Delete trips
- [ ] Analysis: View 7-day and all-time summaries
- [ ] App persists data across launches
- [ ] Export data and verify JSON
- [ ] Import data and verify replacement
