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

- Uses Vision framework for on-device text extraction
- All images and PDFs go through OCR before LLM processing
- Supports both searchable and image-based PDFs
- Text extraction happens locally (no API calls needed)

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

| Operation | Input | Output |
|-----------|-------|--------|
| Extract Receipt | Image/Text | [ExtractedReceiptItem] |
| Extract Nutrition Label | Image/Text | ExtractedNutrition |
| Estimate Nutrition | Food name, category | ExtractedNutrition |
| Match Food | Item name, foods list | Food suggestion |

### Files

- `ProjectX/Services/LLMService.swift` - Protocol and types
- `ProjectX/Services/OpenAIService.swift` - OpenAI implementation
- `ProjectX/Services/ClaudeService.swift` - Claude implementation

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
