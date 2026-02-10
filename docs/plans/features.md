# ProjectX Features Documentation

> Detailed feature documentation. See [main PRD](2025-01-24-mvp-projectx.md) for overview.

---

## Food Category System

Two-level hierarchical category system focused on food types.

### Level 1 - Main Categories

| Category | Icon |
|----------|------|
| Vegetables | leaf.fill |
| Fruits | apple.logo |
| Meat & Poultry | bird.fill |
| Seafood | fish.fill |
| Dairy & Eggs | drop.fill |
| Grains & Bread | basket.fill |
| Legumes & Beans | leaf.circle |
| Nuts & Seeds | seal.fill |
| Oils & Fats | drop.circle |
| Snacks & Sweets | birthday.cake.fill |
| Beverages | cup.and.saucer.fill |
| Other | questionmark.circle |

### Level 2 - Subcategories

Each main category has relevant subcategories:
- Meat: Poultry, Red Meat, Processed Meat
- Dairy: Milk, Cheese, Yogurt, Eggs
- etc.

**Files:**
- `ProjectX/Models/FoodCategory.swift` - Category enums and FoodCategory struct
- `ProjectX/Views/Components/CategoryPicker.swift` - Hierarchical category picker UI

---

## Tag System

Flexible tagging system for food labeling with custom colors.

### Features

- Create custom tags with name and color
- Attach multiple tags to any food
- Filter Food Bank by tags
- Unique tag names enforced at model and UI level
- 9 preset colors available

### Default Tags

| Tag | Color | Purpose |
|-----|-------|---------|
| Organic | Green | Organic foods |
| Local | Teal | Locally sourced |
| High Protein | Orange | Protein-rich foods |
| Low Carb | Blue | Low carbohydrate |
| Plant-Based | Green | Vegan/vegetarian |
| Whole Food | Green | Unprocessed foods |
| Processed | Gray | Processed foods |
| Red Meat | Red | Red meat items |
| High Fiber | Purple | Fiber-rich foods |
| Omega-3 Rich | Teal | Omega-3 sources |
| Low Sodium | Blue | Low sodium foods |
| Sugar-Free | Yellow | No added sugar |

### Files

- `ProjectX/Models/Tag.swift` - Tag model with color support and @Attribute(.unique) on name
- `ProjectX/Views/Components/TagPicker.swift` - Tag selection/creation UI with duplicate validation
- `ProjectX/Services/DefaultDataManager.swift` - Default data management

---

## OCR & Import Features

### OCR Processing

- Uses Apple Vision framework (`VNRecognizeTextRequest`) for on-device text extraction
- All images and PDFs go through OCR before LLM processing
- Text extraction happens locally (no API calls needed)
- Supports both searchable and image-based PDFs (PDF rendered to image via `PDFHelper`)

### OCR+Image Dual-Input for LLM

Every image-based or PDF-based LLM call uses a dual-input approach: OCR-extracted text is appended to the prompt alongside the original image/document sent to the LLM.

**Rationale:** LLM vision capabilities can miss or misread text in images, especially on receipts with small print, unusual fonts, or low contrast. Running on-device OCR first and including the extracted text gives the LLM two complementary signals, improving accuracy for item names, prices, and nutrition values.

**How it works:**
1. Before each vision API call, `OCRService.extractText()` runs on the image
2. If OCR succeeds, the extracted text is appended to the prompt (e.g., `\n\nOCR extracted text from image:\n{text}`)
3. The image is still sent as before -- the LLM receives both image and OCR text
4. If OCR fails or returns empty, the original prompt is used unchanged (graceful fallback)

**Long-image segmentation:**
- Tall images (aspect ratio > 3.0, height > 4000px) are segmented into overlapping sections
- Each segment is OCR'd separately, then results are merged with boundary deduplication
- This handles long grocery receipts that exceed Vision framework limits

**Coverage:** All image/PDF LLM paths are covered via the service layer:
- `OpenAIService.sendVisionRequest` -- augments prompt with OCR before API call
- `ClaudeService.sendVisionRequest` -- same pattern for image requests
- `ClaudeService.sendPDFRequest` -- OCR on PDF-rendered image before native PDF API call
- OpenAI PDF path converts to image via `PDFHelper`, then goes through `sendVisionRequest`

### Import Options

| Option | Description |
|--------|-------------|
| Take Photo | Camera capture |
| Choose from Library | Photo picker |
| Import PDF or Image | Document picker |
| Enter Text | Manual text input |
| Share from other apps | URL handling |

### Scan Type Selection

After OCR, user chooses:
- **Receipt**: Extracts grocery items with prices and quantities
- **Nutrition Label**: Extracts per-100g nutrition values

### Files

- `ProjectX/Services/OCRService.swift` - Vision-based text extraction
- `ProjectX/Services/ImportManager.swift` - Import handling and document picker
- `ProjectX/Views/Scan/ScanView.swift` - Import flow with OCR

---

## Data Export/Import

Full data export and import functionality with selective data type support.

### Export Features

- Multi-select data types: Food Bank, Tags, Grocery Trips
- JSON format with ISO8601 dates
- Export via iOS Share Sheet
- Filename: `ProjectX-Export-YYYY-MM-DD.json`

### Import Features

- File picker for JSON imports
- Preview imported data before confirming
- Multi-select which data types to import
- Replace existing items with same name (not skip)
- Maintains food-tag relationships during import

### Export JSON Structure

```json
{
  "version": "1.0",
  "exportDate": "2025-01-24T12:00:00Z",
  "tags": [
    {"name": "Organic", "colorHex": "34C759"}
  ],
  "foods": [
    {
      "name": "Apple",
      "categoryRaw": "fruits",
      "nutrition": {...},
      "tagNames": ["Organic", "Local"]
    }
  ],
  "trips": [
    {
      "id": "...",
      "date": "...",
      "storeName": "...",
      "items": [...]
    }
  ]
}
```

### Unique Constraints

- `@Attribute(.unique)` on `Tag.name` and `Food.name` at model level
- UI validation prevents duplicate names when creating tags
- Import replaces existing items with matching names

### Files

- `ProjectX/Services/DataExportService.swift` - Export/import service with Codable structures
- `ProjectX/Views/Settings/SettingsView.swift` - Export/import UI sheets

---

## Shared Components

Reusable UI components for code simplification.

### TextInputSheet

Shared text input sheet for receipt text and nutrition label text entry.

**File:** `ProjectX/Views/Components/TextInputSheet.swift`

### NutritionFieldRow

Nutrition input row component used in FoodDetailView and NutritionFormSection.

**File:** `ProjectX/Views/Components/NutritionFieldRow.swift`

### TagPicker

Flow layout tag picker with inline creation.

**File:** `ProjectX/Views/Components/TagPicker.swift`

### CategoryPicker

Two-level hierarchical category picker.

**File:** `ProjectX/Views/Components/CategoryPicker.swift`

### FlowLayout

Custom SwiftUI Layout for tag chips.

**File:** `ProjectX/Views/Components/TagPicker.swift` (embedded)

---

## LLM Integration

### Supported Providers & Models

**OpenAI Models:**
| Model | ID | Vision Support |
|-------|-----|----------------|
| GPT-4o (Recommended) | gpt-4o | Yes |
| GPT-4o Mini | gpt-4o-mini | Yes |
| GPT-4 Turbo | gpt-4-turbo | Yes |
| GPT-3.5 Turbo | gpt-3.5-turbo | No |

**Claude Models:**
| Model | ID | Vision Support |
|-------|-----|----------------|
| Claude Sonnet 4 (Recommended) | claude-sonnet-4-20250514 | Yes |
| Claude Opus 4 | claude-opus-4-20250514 | Yes |
| Claude 3.5 Haiku | claude-3-5-haiku-20241022 | Yes |
| Claude 3.5 Sonnet | claude-3-5-sonnet-20241022 | Yes |

### Model Selection

- Each provider has configurable model selection
- Model preference persisted in UserDefaults
- Warning shown when selected model doesn't support vision (image scanning)

### API Key Storage

- Keys stored in iOS Keychain
- Provider selection in UserDefaults
- Validation on save with test API call

### LLM Operations

| Operation | Input | Output | OCR Pre-processing |
|-----------|-------|--------|--------------------|
| Extract Receipt | Image/Text/PDF | [ExtractedReceiptItem] | Yes (image/PDF) |
| Extract Nutrition Label | Image/Text/PDF | ExtractedNutrition | Yes (image/PDF) |
| Estimate Nutrition | Food name, category | ExtractedNutrition | No (text-only) |
| Fill Empty Nutrition | Food name, existing values | ExtractedNutrition | No (text-only) |
| Match Food | Item name, foods list | Food suggestion | No (text-only) |
| Suggest Category/Tags | Food name, available tags | SuggestedFoodInfo | No (text-only) |
| Suggest Nutrition Targets | Family member profiles | SuggestedNutritionTargets | No (text-only) |

Image and PDF operations automatically run on-device OCR via `OCRService` and append the extracted text to the LLM prompt alongside the image. See [OCR+Image Dual-Input](#ocr--import-features) for details.

### Files

- `ProjectX/Services/LLMService.swift` - Protocol and types
- `ProjectX/Services/OpenAIService.swift` - OpenAI implementation (with OCR augmentation)
- `ProjectX/Services/ClaudeService.swift` - Claude implementation (with OCR augmentation)
- `ProjectX/Services/OCRService.swift` - Vision framework OCR with long-image segmentation

---

## Data Models

### NutritionInfo Fields

All nutrition values are stored per 100g.

**Source Tracking:**
| Source | Icon | Description |
|--------|------|-------------|
| AI Estimate | sparkles | Nutrition estimated by LLM |
| Label Scan | camera.viewfinder | Extracted from nutrition label image/text |
| Manual Entry | pencil | Entered manually by user |

**Macronutrients:**
| Field | Unit | Description |
|-------|------|-------------|
| calories | kcal | Energy |
| protein | g | Protein content |
| carbohydrates | g | Total carbs |
| fat | g | Total fat |
| saturatedFat | g | Saturated fat (sub-fat) |
| omega3 | g | Omega-3 fatty acids (sub-fat) |
| omega6 | g | Omega-6 fatty acids (sub-fat) |
| sugar | g | Total sugars (sub-carb) |
| fiber | g | Dietary fiber (sub-carb) |
| sodium | mg | Sodium |

**Micronutrients:**
| Field | Unit | Description |
|-------|------|-------------|
| vitaminA | mcg | Vitamin A |
| vitaminC | mg | Vitamin C |
| vitaminD | mcg | Vitamin D |
| calcium | mg | Calcium |
| iron | mg | Iron |
| potassium | mg | Potassium |

### Core Models

| Model | Purpose | Unique Keys |
|-------|---------|-------------|
| Food | Food bank entries | id, name |
| Tag | Food labels | id, name |
| GroceryTrip | Shopping trips | id |
| PurchasedItem | Trip items | id |
| NutritionInfo | Nutrition per 100g | - |
| AppSettings | App configuration | - |

### Relationships

```
Food --< Tag (many-to-many)
GroceryTrip --< PurchasedItem (one-to-many, cascade delete)
PurchasedItem --> Food (optional)
Food --> NutritionInfo (one-to-one, cascade delete)
```

### Files

- `ProjectX/Models/Food.swift`
- `ProjectX/Models/Tag.swift`
- `ProjectX/Models/GroceryTrip.swift`
- `ProjectX/Models/NutritionInfo.swift`
- `ProjectX/Models/NutritionSummary.swift`
- `ProjectX/Models/FoodCategory.swift`
- `ProjectX/Models/FamilyMember.swift`

---

## Family Nutrition Guide

Multi-step wizard that collects family member profiles and uses LLM to generate personalized daily nutrition targets.

### Family Member Profile

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| name | String | Display name (e.g., "Dad", "Mom", "Emma") |
| age | Int | Age in years |
| weight | Double | Weight in kg |
| activityLevel | ActivityLevel | Physical activity level |
| dietType | DietType | Dietary preference |

### Activity Levels

| Level | Description | Multiplier |
|-------|-------------|------------|
| Sedentary | Little or no exercise | 1.2 |
| Lightly Active | Light exercise 1-3 days/week | 1.375 |
| Moderately Active | Moderate exercise 3-5 days/week | 1.55 |
| Active | Hard exercise 6-7 days/week | 1.725 |
| Very Active | Very hard exercise, physical job | 1.9 |

### Diet Types

| Type | Description |
|------|-------------|
| Standard | Balanced macros, no restrictions |
| Vegetarian | No meat, includes dairy/eggs |
| Vegan | No animal products |
| Keto | Very low carb, high fat |
| Mediterranean | High in olive oil, fish, vegetables |
| High Protein | Higher protein for muscle building |
| Low Sodium | Reduced sodium intake |

### Wizard Steps

1. **Members**: Add/edit family members (name, age, weight)
2. **Details**: For each member, set activity level and diet preference
3. **Review**: Summary of all members and their profiles
4. **Generate**: LLM analyzes profiles and suggests nutrition targets
5. **Edit**: Adjust suggested targets before saving

### LLM Suggestion

**Input to LLM:**
```json
{
  "familyMembers": [
    {
      "name": "Dad",
      "age": 40,
      "weight": 80,
      "activityLevel": "moderatelyActive",
      "dietType": "standard"
    },
    {
      "name": "Mom",
      "age": 38,
      "weight": 60,
      "activityLevel": "lightlyActive",
      "dietType": "mediterranean"
    }
  ]
}
```

**Output from LLM:**
```json
{
  "calories": 3200,
  "protein": 120,
  "carbohydrates": 400,
  "fat": 100,
  "sugar": 50,
  "fiber": 50,
  "sodium": 4600,
  "explanation": "Combined daily targets for a 2-person household..."
}
```

### User Actions

- **Redo Guide**: Restart wizard from step 1
- **Get New Suggestion**: Regenerate LLM recommendation with current profiles
- **Edit Members**: Modify individual family member profiles
- **Manual Override**: Adjust any suggested values before saving

### Data Storage

- Family members stored in UserDefaults as JSON array
- `hasCompletedFamilyGuide` flag tracks completion
- Generated targets saved to existing `dailyNutritionTarget`

### Files

- `ProjectX/Models/FamilyMember.swift` - FamilyMember struct, DietType enum
- `ProjectX/Services/AppSettings.swift` - familyMembers storage, guide completion flag
- `ProjectX/Services/LLMService.swift` - suggestNutritionTargets method
- `ProjectX/Views/Settings/FamilyGuideView.swift` - Wizard UI

---

## Meal Tracking Mode

Track individual food consumption by meals as an alternative to grocery trip tracking. Users can mix both input methods within a profile.

### Meal Types

| Type | Icon | Default Time |
|------|------|--------------|
| Breakfast | sunrise.fill | 8:00 |
| Lunch | sun.max.fill | 12:30 |
| Dinner | moon.stars.fill | 19:00 |
| Snack | carrot.fill | 15:00 |

### Meal vs Trip Comparison

| Aspect | Grocery Trip | Meal |
|--------|--------------|------|
| Purpose | Track shopping purchases | Track consumption |
| Price | Yes (per item) | No |
| Metadata | Store name | Meal type |
| Time | Date per trip | Date + meal type |
| Focus | What was bought | What was eaten |

### Meal Entry

| Field | Type | Required |
|-------|------|----------|
| date | Date | Yes |
| mealType | MealType | Yes |
| notes | String | No |
| items | [MealItem] | Yes |

### Meal Item

| Field | Type | Description |
|-------|------|-------------|
| name | String | Item name |
| quantity | Double | Weight in grams |
| food | Food? | Link to Food Bank |
| isSkipped | Bool | Exclude from totals |

### User Flow

1. Tap Meals tab → Add Meal
2. Select meal type (breakfast/lunch/dinner/snack)
3. Add items via AI (photo/text/voice) or manually
4. Link items to Food Bank for nutrition data
5. Save meal

### Analysis Integration

- Analysis view has data source filter: All / Trips only / Meals only
- Nutrition summaries combine data from both sources when "All" selected
- Nutrition breakdown by category includes both trips and meals

### Files

- `ProjectX/Models/Meal.swift` - Meal, MealItem, MealType
- `ProjectX/Views/Meals/MealsView.swift` - Meal list
- `ProjectX/Views/Meals/MealDetailView.swift` - Create/edit meal
- `ProjectX/Models/NutritionSummary.swift` - forMeals(), combined() methods

---

## Multi-Profile Support

Support multiple user profiles for isolated consumption tracking while sharing the Food Bank.

### Profile Data

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| name | String | Display name (e.g., "Dad", "Mom") |
| iconName | String | SF Symbol name |
| colorHex | String | Accent color (hex) |
| isDefault | Bool | Default profile flag |

### Data Isolation

**Profile-Specific (Isolated):**
- Grocery trips and items
- Meals and items
- Family members (for nutrition guide)
- Nutrition targets
- Family guide completion

**Shared (App-wide):**
- Food Bank (foods, nutrition)
- Tags
- Custom subcategories
- LLM settings (provider, API keys, model)
- General preferences

### Profile Icons

Available SF Symbols for profile icons:
- person.fill
- figure.stand
- figure.2.arms.open
- face.smiling
- star.fill
- heart.fill
- leaf.fill

### Profile Colors

| Name | Hex |
|------|-----|
| Blue | #007AFF |
| Green | #34C759 |
| Purple | #AF52DE |
| Orange | #FF9500 |
| Pink | #FF2D55 |
| Teal | #5AC8FA |

### User Flow

1. First launch → Default profile created
2. Settings → Profiles → Add/edit/delete profiles
3. Profile switcher in nav bar → Quick switch
4. Each profile sees only their trips/meals
5. Food Bank shared across all profiles

### Files

- `ProjectX/Models/Profile.swift` - Profile model
- `ProjectX/Views/Settings/ProfilesView.swift` - Profile management
- `ProjectX/Views/Components/ProfileSwitcher.swift` - Quick switch UI
- `ProjectX/Services/AppSettings.swift` - Profile-keyed settings

See [Multi-Profile Implementation Plan](multi-profile-implementation.md) for detailed implementation guide.
