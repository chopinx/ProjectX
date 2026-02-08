# ProjectX - Product Requirements Document

## Overview

**Product Name:** ProjectX (working title)
**Platform:** iOS (iPhone & iPad)
**Version:** 1.0

### Problem Statement

Tracking household nutrition is tedious. People buy groceries but have no easy way to understand the nutritional profile of what they're purchasing over time. Manual food logging apps require per-meal input, which most households won't sustain.

### Solution

A diet management app that extracts food items from grocery receipt photos, maintains a household food bank with nutrition data, and provides insights into nutrition trends over time. Uses LLM APIs to handle the complexity of receipt parsing, food matching, and nutrition estimation.

---

## Target Users

**Primary:** Households (2+ people) who want to track nutrition at the grocery purchase level, not individual meals.

**Use Pattern:**
- Scan receipt after each grocery trip (1-3 times per week)
- Occasionally scan nutrition labels for new products
- Review weekly/monthly nutrition trends

**Geography:** Initially German supermarkets (REWE, Edeka, Lidl, Aldi), but architecture supports any language (LLM translates to English).

---

## Core Features

### F1: Receipt Scanning & Extraction

**Description:** User takes a photo or selects a screenshot of a grocery receipt. LLM extracts structured item list.

**Input:**
- Photo from camera
- Image from photo library
- Screenshot

**Output (per item):**
- Product name (translated to English)
- Quantity in grams (LLM converts all weights to grams)
- Price
- Category (produce, dairy, meat, etc.)

**Unit Standardization:**
All quantities are stored in **grams (g)** only. The LLM converts any weight/quantity from receipts:
- "1 kg" → 1000g
- "500 ml" → 500g (approximate, liquids treated as 1ml ≈ 1g)
- "2 pcs" → LLM estimates weight per piece (e.g., "2 apples" → 360g)
- "1.5 L" → 1500g

This simplifies nutrition calculations: `nutrition per 100g × (quantity_grams / 100)`

**User Flow:**
1. Tap "Scan Receipt" on home screen
2. Take photo or select from library
3. Loading state while LLM processes
4. Editable list appears with extracted items
5. For each item, user can:
   - Edit name, quantity, price
   - Change/search matched food from food bank
   - Skip item (don't track)
   - Delete item
6. Add missing items manually
7. Tap "Save" to confirm grocery trip

**Edge Cases:**
- Blurry/partial receipt → Show error, let user retry or enter manually
- Item not in food bank → Trigger new food flow (F3)
- LLM extraction errors → User edits in review step

---

### F2: Food Bank

**Description:** Local database of foods with nutrition information per 100g. Syncs across user's Apple devices via iCloud.

**Food Entry Fields:**
- Name (English)
- Category (produce, dairy, meat, bakery, beverages, snacks, frozen, pantry, other)
- Nutrition per 100g:
  - Calories (kcal)
  - Protein (g)
  - Carbohydrates (g)
  - Fat (g)
  - Saturated fat (g)
  - Sugar (g)
  - Fiber (g)
  - Sodium (mg)

**User Capabilities:**
- Browse all foods (grouped by category)
- Search foods by name
- Edit any food's nutrition data
- Delete foods
- Add foods manually

**Matching Logic:**
- When receipt item is extracted, LLM matches to existing food bank entries
- LLM returns confidence score and best match
- User can override match by searching food bank

---

### F3: New Food Addition

**Description:** When a receipt item doesn't match existing foods, user adds it to the food bank.

**Options for Nutrition Data:**

**Option A - LLM Estimate:**
1. LLM generates baseline nutrition estimate based on food name/category
2. Popup shows estimated values (all editable)
3. User can adjust any values
4. User confirms to save to food bank

**Option B - Scan Nutrition Label:**
1. User taps "Scan Label" in popup
2. Takes photo of product's nutrition label
3. LLM extracts nutrition values
4. Popup shows extracted values (all editable)
5. User confirms to save to food bank

**Option C - Manual Entry:**
1. User manually enters all nutrition values
2. Saves to food bank

**User can choose not to save to food bank** (one-time tracking only).

---

### F4: Grocery Trip Management

**Description:** Each receipt scan creates a grocery trip record.

**Trip Fields:**
- Date
- Store name (optional, LLM extracts if present)
- Total spent (calculated from items)
- Items (linked to food bank entries)

**User Capabilities:**
- View list of past trips
- View trip details (items, prices, nutrition summary)
- Edit past trips (add/remove/edit items)
- Delete trips

---

### F5: Nutrition Analysis

**Description:** Charts and statistics showing nutrition trends over time.

**Time Periods:**
- Weekly view (default, matches shopping rhythm)
- Monthly view
- Custom date range picker

**Visualizations:**

**Summary Stats:**
- Total calories for period
- Average daily calories (total / days in period)
- Total spent on groceries

**Macro Breakdown:**
- Pie chart: protein vs carbs vs fat (by calories)
- Bar chart: grams of each macro

**Health Markers:**
- Bar chart comparing:
  - Sodium (mg)
  - Saturated fat (g)
  - Sugar (g)
  - Fiber (g)
- Color coding: green (good), yellow (moderate), red (high) based on general guidelines

**Trends:**
- Line chart comparing current period to previous period
- Week-over-week or month-over-month comparison

---

### F6: Settings

**Description:** App configuration.

**Settings:**
- **LLM Provider:** OpenAI or Claude (Anthropic)
- **API Key:** User enters their own API key (stored securely in Keychain)
- **Family Nutrition Guide:** Launch guided setup for family targets
- **iCloud Sync:** Toggle on/off
- **About:** App version, privacy policy, credits

---

### F7: Family Nutrition Guide

**Description:** A multi-step wizard that collects family member profiles and uses LLM to generate personalized daily nutrition targets for the household.

**Family Member Profile:**
- Name (e.g., "Dad", "Mom", "Emma")
- Age (years)
- Weight (kg)
- Activity level (Sedentary, Lightly Active, Moderately Active, Active, Very Active)
- Diet type (Standard, Vegetarian, Vegan, Keto/Low-Carb, Mediterranean, High Protein, Low Sodium)

**Wizard Flow:**
1. **Members Step:** Add/edit family members (name, age, weight)
2. **Details Step:** For each member, set activity level and diet preference
3. **Review Step:** Summary of all members and their profiles
4. **Generate Step:** LLM analyzes profiles and suggests aggregated daily nutrition targets
5. **Edit Step:** User can adjust the suggested targets before saving

**LLM Suggestion:**
- Input: All family member profiles (age, weight, activity, diet type)
- Output: Recommended daily targets for the whole household:
  - Calories, Protein, Carbohydrates, Fat, Sugar, Fiber, Sodium
  - Brief explanation of the recommendation

**User Capabilities:**
- Add/remove/edit family members at any time
- Re-run the guide to get fresh LLM suggestions
- Manually override any suggested values
- "Redo Guide" button to restart the wizard
- "Get New Suggestion" button to regenerate LLM recommendation with current profiles

**Data Storage:**
- Family member profiles persisted in UserDefaults
- Generated targets saved to existing `dailyNutritionTarget` in AppSettings
- `hasCompletedFamilyGuide` flag tracks completion status

---

## Technical Requirements

### Platform & Frameworks
- iOS 17+ (for latest SwiftData features)
- SwiftUI for all UI
- SwiftData for persistence
- CloudKit for iCloud sync
- Vision framework for OCR text extraction from receipts

### Architecture: Interface-First Design
Code against protocols/interfaces, not concrete implementations. This enables:
- Easy testing with mock implementations
- Swappable components (e.g., different LLM providers)
- Clear contracts between layers

**Key Interfaces:**
```swift
protocol LLMService {
    func extractReceiptItems(from text: String) async throws -> [ExtractedReceiptItem]
    func extractNutritionLabel(from image: UIImage) async throws -> NutritionInfo
    func estimateNutrition(for foodName: String) async throws -> NutritionInfo
}

protocol ReceiptScanner {
    func scan(image: UIImage) async throws -> [ExtractedReceiptItem]
}

protocol NutritionEstimator {
    func estimate(for foodName: String, category: FoodCategory) async throws -> NutritionInfo
}
```

### LLM Integration
- Support OpenAI API (GPT-4o-mini for text, GPT-4o for vision)
- Support Anthropic API (Claude 3.5 Sonnet)
- User provides their own API key
- Protocol-based abstraction to swap providers easily

### Data Storage
- All data stored locally on device (SwiftData)
- iCloud sync via CloudKit (automatic with SwiftData)
- API keys stored in iOS Keychain (secure)

### Language
- App UI: English only
- Data storage: English only
- Receipt input: Any language (LLM translates to English)

---

## Data Models

### GroceryTrip
```
- id: UUID
- date: Date
- storeName: String?
- receiptImageData: Data?
- items: [PurchasedItem]
- createdAt: Date
- updatedAt: Date
```

### PurchasedItem
```
- id: UUID
- name: String (as extracted/edited)
- quantity: Double (always in grams - LLM converts all units to grams)
- price: Double
- food: Food? (link to food bank, nil if skipped)
- trip: GroceryTrip
```

### Food
```
- id: UUID
- name: String (English)
- category: FoodCategory (enum)
- nutrition: NutritionInfo
- isUserCreated: Bool
- createdAt: Date
- updatedAt: Date
```

### NutritionInfo
```
- calories: Double (kcal per 100g)
- protein: Double (g per 100g)
- carbohydrates: Double (g per 100g)
- fat: Double (g per 100g)
- saturatedFat: Double (g per 100g)
- sugar: Double (g per 100g)
- fiber: Double (g per 100g)
- sodium: Double (mg per 100g)
```

### FoodCategory (enum)
```
- produce
- dairy
- meat
- seafood
- bakery
- beverages
- snacks
- frozen
- pantry
- other
```

### FamilyMember
```
- id: UUID
- name: String (e.g., "Dad", "Mom", "Emma")
- age: Int (years)
- weight: Double (kg)
- activityLevel: ActivityLevel (enum)
- dietType: DietType (enum)
```

### ActivityLevel (enum)
```
- sedentary
- lightlyActive
- moderatelyActive
- active
- veryActive
```

### DietType (enum)
```
- standard
- vegetarian
- vegan
- keto
- mediterranean
- highProtein
- lowSodium
```

### Profile
```
- id: UUID
- name: String (e.g., "Dad", "Mom", "Kids")
- iconName: String (SF Symbol name)
- colorHex: String (hex color code)
- isDefault: Bool
- createdAt: Date
```

### Meal
```
- id: UUID
- date: Date
- mealType: MealType (breakfast, lunch, dinner, snack)
- notes: String?
- items: [MealItem]
- profile: Profile (optional, for profile isolation)
- createdAt: Date
- updatedAt: Date
```

### MealItem
```
- id: UUID
- name: String (as extracted/edited)
- quantity: Double (always in grams)
- food: Food? (link to food bank, nil if not linked)
- meal: Meal
- isSkipped: Bool
```

### MealType (enum)
```
- breakfast (icon: sunrise.fill)
- lunch (icon: sun.max.fill)
- dinner (icon: moon.stars.fill)
- snack (icon: carrot.fill)
```

---

## User Interface

### Tab Bar Structure
1. **Trips** - Dashboard with recent grocery trips, quick stats
2. **Meals** - Meal tracking with breakfast/lunch/dinner/snack entries
3. **Foods** - Browse, search, manage Food Bank
4. **Analysis** - Charts and trends (with data source filter)
5. **Settings** - API keys, profiles, preferences

**Profile Switcher:** Available in navigation bar to quickly switch between profiles.

### Key Screens

**Home Screen:**
- Weekly nutrition summary card (calories, macros)
- Recent grocery trips list (last 5)
- "Scan Receipt" floating action button

**Scan Flow:**
- Full-screen camera with capture button
- Option to select from photo library
- Processing indicator with "Analyzing receipt..."
- Editable item list (table view)
- Item edit sheet (popup)
- New food sheet (popup with LLM estimate / scan label options)

**Food Bank Screen:**
- Search bar at top
- Segmented control for category filter
- List of foods with name and calorie info
- Tap to view/edit food details

**Analysis Screen:**
- Period selector (Week / Month / Custom)
- Date navigation (< current period >)
- Summary stats cards
- Macro pie chart
- Health markers bar chart
- Period comparison (expandable)

**Settings Screen:**
- LLM Provider picker
- API Key text field (secure)
- iCloud sync toggle
- About section

---

## Non-Functional Requirements

### Performance
- Receipt processing: < 10 seconds (dependent on LLM API)
- App launch: < 2 seconds
- Smooth 60fps scrolling on all lists

### Security
- API keys stored in iOS Keychain
- No analytics or tracking
- All data stays on device + user's iCloud

### Privacy
- Receipt images stored locally only (not sent anywhere except LLM API for processing)
- No account required
- No server-side storage (except user's own iCloud)

### Offline Support
- App fully functional offline (browse data, view analysis)
- Receipt scanning requires internet (LLM API call)
- Queued scans processed when back online (stretch goal)

---

### F8: Meal Tracking Mode

**Description:** Track individual food consumption by meals (breakfast, lunch, dinner, snack), separate from grocery trip tracking. Meals focus on nutrition only (no prices).

**Meal Entry Fields:**
- Date and time
- Meal type (breakfast, lunch, dinner, snack)
- Items (linked to Food Bank)
- Notes (optional)

**Meal Item Fields:**
- Name (as entered/extracted)
- Quantity in grams
- Linked food (optional, for nutrition calculation)
- Skip flag (exclude from totals)

**User Capabilities:**
- Add meals manually or via AI (photo/text/voice)
- Review and edit meal items
- Link items to Food Bank for nutrition data
- View meal history sorted by date
- Delete meals

**Key Differences from Grocery Trips:**

| Aspect | Grocery Trip | Meal |
|--------|--------------|------|
| Focus | Shopping (price + nutrition) | Consumption (nutrition only) |
| Metadata | Store name | Meal type |
| Item data | Has price | No price |
| Time | Date per trip | Date + meal type |

---

### F9: Multi-Profile Support

**Description:** Support multiple user profiles within the app. Each profile has isolated consumption data while sharing the Food Bank.

**Profile Fields:**
- Name (e.g., "Dad", "Mom", "Kids")
- Icon (SF Symbol)
- Color (accent color)
- Is default flag

**Profile-Specific Data (Isolated):**
- Grocery trips and items
- Meals and items
- Family members (for nutrition guide)
- Nutrition targets
- Family guide completion status

**Shared Data (App-wide):**
- Food Bank (foods, nutrition info)
- Tags
- Food categories
- LLM provider settings
- API keys
- General app preferences

**User Capabilities:**
- Create/edit/delete profiles
- Switch between profiles quickly
- Set a default profile
- Each profile sees only their trips, meals, and targets
- All profiles share the same Food Bank

**Use Cases:**
- Family members tracking their own meals
- Separate work vs personal tracking
- Kids vs adults with different targets

---

## Out of Scope (v1.0)

- Barcode scanning
- Recipe creation/meal planning
- Shopping list generation
- Social features / sharing
- Android version
- Web dashboard
- Goal alerts/notifications (targets are set but no push alerts)
- Integration with health apps (Apple Health)

---

## Success Metrics

- User can scan receipt and save grocery trip in < 2 minutes
- 90%+ of receipt items correctly extracted (user makes < 10% edits)
- User engages with analysis at least weekly
- Food bank grows to 100+ items within first month of use

---

## Open Questions

1. **App name:** "ProjectX" is a working title. Final name TBD.
2. **Monetization:** None planned for v1. User pays for their own LLM API usage.
3. **Nutrition guidelines:** Should we show recommended daily values? Which standard (WHO, FDA, EU)?
4. **Receipt image storage:** Keep original images or delete after extraction to save space?

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-01-24 | 0.1 | Initial draft |
| 2025-01-24 | 0.2 | Clarified unit standardization: all quantities stored in grams only. LLM converts kg/L/ml/pcs to grams. Removed unit field from PurchasedItem. |
| 2025-01-24 | 0.3 | Added interface-first architecture section with key protocols (LLMService, ReceiptScanner, NutritionEstimator). Updated Vision framework role to OCR. |
| 2025-01-25 | 0.4 | Added F7: Family Nutrition Guide - multi-step wizard for family member profiles with LLM-generated nutrition targets. Added FamilyMember, ActivityLevel, DietType data models. |
| 2025-02-01 | 0.5 | Added F8: Meal Tracking Mode - track consumption by meals (breakfast/lunch/dinner/snack) as alternative to grocery trips. Both are consumption input methods users can mix. Added Meal, MealItem, MealType data models. |
| 2025-02-01 | 0.6 | Added F9: Multi-Profile Support - isolated consumption data (trips, meals, targets) per profile while sharing Food Bank. Added Profile data model. Updated tab bar structure. |
