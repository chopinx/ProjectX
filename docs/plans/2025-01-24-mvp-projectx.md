# ProjectX MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build an MVP diet management app that scans grocery receipts via LLM, extracts food items, maintains a household Food Bank with nutrition data, and shows nutrition summaries over time.

**Architecture:** Single iOS 17+ SwiftUI app using SwiftData for local persistence. LLM service abstraction supporting OpenAI and Claude APIs. Tab-based navigation: Home, Scan, Food Bank, Analysis, Settings.

**Tech Stack:** Swift 5.9+, SwiftUI, SwiftData, PhotosUI, XCTest, Xcode 15+, iOS 17 simulator.

---

## Documentation

| Document | Description |
|----------|-------------|
| [Implementation Tasks](implementation-tasks.md) | Detailed task breakdown (Tasks 1-9) |
| [Features](features.md) | Feature documentation and specifications |
| [Multi-Profile Implementation](multi-profile-implementation.md) | Multi-profile support implementation plan |

---

## Alignment with PRD

- **Grams only:** All quantities stored in grams. LLM converts all units (kg, L, pcs) to grams.
- **Nutrition per 100g:** All nutrition values are per 100g, scaled by `quantity / 100`.
- **LLM Integration:** Receipt scanning, nutrition estimation, food matching.
- **Secure API Keys:** Stored in iOS Keychain.
- **Simplified Analysis:** MVP shows all-time and last-7-days summaries (charts deferred).

---

## MVP Features Summary

1. SwiftData models: Food, NutritionInfo, GroceryTrip, PurchasedItem, Tag, Meal, MealItem, Profile
2. All quantities in grams (LLM converts from kg/L/pcs)
3. LLM service layer: OpenAI + Claude support with model selection (see [Features](features.md#llm-integration))
4. Secure API key storage via Keychain with validation
5. Receipt scanning with AI extraction (image or text input)
6. Receipt review flow with food matching and auto-matching
7. Food Bank with AI nutrition estimation + label scanning
8. Nutrition analysis (7-day + all-time) with pie charts
9. Two-level food category system (see [Features](features.md#food-category-system))
10. Tag system for food labeling (see [Features](features.md#tag-system))
11. Default data management with restore functionality
12. Data export/import (see [Features](features.md#data-exportimport))
13. Family Nutrition Guide with LLM-generated targets (see [Features](features.md#family-nutrition-guide))
14. Receipt draft persistence (resume editing after app switch)
15. Baby food filter setting
16. Multi-select batch operations for receipt items and Food Bank
17. Separate AI buttons for category/tags vs nutrition estimation
18. Tag & Category management view (create, edit, delete tags; view category hierarchy)
19. Multi-photo nutrition label scanning (capture or select multiple photos, OCR combined)
20. AI-powered trip item addition (multi-photo, text input, voice input via Speech framework)
21. AI food matching suggestions when linking items to Food Bank
22. Review/edit flow after AI extraction (review each item before adding to trip)
23. LLM weight estimation based on typical package sizes when weight not on receipt
24. Meal tracking mode (breakfast/lunch/dinner/snack) - alternative consumption input (see [Features](features.md#meal-tracking-mode))
25. Multi-profile support - isolated consumption data, shared Food Bank (see [Features](features.md#multi-profile-support))

---

## Use Cases

| Use Case | Status |
|----------|--------|
| Scan receipt photo | Yes |
| Enter receipt text | Yes |
| LLM extracts items (translated, grams) | Yes |
| Review/edit extracted items | Yes |
| Link items to Food Bank | Yes |
| Add new food with AI estimate | Yes |
| Scan nutrition label (image or text) | Yes |
| Manual food entry | Yes |
| View grocery trips | Yes |
| View trip nutrition | Yes |
| View 7-day summary | Yes |
| View all-time summary | Yes |
| Secure API key storage | Yes |
| API key validation on save | Yes |
| Two-level food categories | Yes |
| Tag foods with custom labels | Yes |
| Filter by category/tag | Yes |
| Restore default tags | Yes |
| Export data (selective) | Yes |
| Import data (selective) | Yes |
| Family nutrition guide wizard | Yes |
| Per-member profiles (age, weight, activity, diet) | Yes |
| LLM-generated nutrition targets | Yes |
| Redo guide / regenerate suggestions | Yes |
| Multi-select delete receipt items | Yes |
| Multi-select delete foods | Yes |
| Batch AI category/tags for foods | Yes |
| Batch AI nutrition estimation | Yes |
| Receipt draft persistence | Yes |
| Baby food filter setting | Yes |
| Manage tags (create, edit, delete) | Yes |
| View category hierarchy | Yes |
| Multi-photo nutrition label scan | Yes |
| Add trip items via AI (photo/text/voice) | Yes |
| Voice input for item entry | Yes |
| AI food matching suggestions | Yes |
| Review extracted items before adding | Yes |
| LLM estimates weight from package info | Yes |
| Track meals (breakfast/lunch/dinner/snack) | Yes |
| Mix trips and meals as consumption inputs | Yes |
| Create/manage profiles | Yes |
| Switch between profiles | Yes |
| Isolated consumption data per profile | Yes |
| Shared Food Bank across profiles | Yes |

---

## File Structure

```
ProjectX/
├── Models/
│   ├── Food.swift
│   ├── Tag.swift
│   ├── GroceryTrip.swift
│   ├── PurchasedItem.swift
│   ├── Meal.swift                    # Meal, MealItem, MealType
│   ├── Profile.swift                 # Profile model (planned)
│   ├── NutritionInfo.swift
│   ├── NutritionSummary.swift
│   ├── FoodCategory.swift
│   └── FamilyMember.swift
├── Services/
│   ├── AppSettings.swift
│   ├── LLMService.swift
│   ├── OpenAIService.swift
│   ├── ClaudeService.swift
│   ├── OCRService.swift
│   ├── ImportManager.swift
│   ├── DataExportService.swift
│   └── DefaultDataManager.swift
├── Utils/
│   └── KeychainHelper.swift
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── TripDetailView.swift
│   │   ├── ItemEditView.swift
│   │   └── AddItemsSheet.swift
│   ├── Meals/                        # New - Meal tracking
│   │   ├── MealsView.swift
│   │   └── MealDetailView.swift
│   ├── Scan/
│   │   ├── NutritionLabelScanView.swift
│   │   ├── MultiPhotoPicker.swift
│   │   └── FoodMatchingSheet.swift
│   ├── FoodBank/
│   │   ├── FoodBankView.swift
│   │   └── FoodDetailView.swift
│   ├── Analysis/
│   │   └── AnalysisView.swift
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── FamilyGuideView.swift
│   │   └── ProfilesView.swift        # Planned - Profile management
│   └── Components/
│       ├── VoiceInputButton.swift
│       ├── SharedComponents.swift
│       └── ProfileSwitcher.swift     # Planned - Quick profile switch
├── ProjectXApp.swift
└── ContentView.swift
```

---

## Build & Test

```bash
# Build
xcodebuild build -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17'

# Test
xcodebuild test -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17'
```

See [Implementation Tasks](implementation-tasks.md#task-9-final-integration--qa) for QA checklist.
