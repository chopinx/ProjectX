# CLAUDE.md - ProjectX

## Overview

ProjectX is an iOS diet management app built with SwiftUI and SwiftData (iOS 17+). It helps users track nutrition by scanning grocery receipts, managing a food database, and analyzing nutritional intake.

## Build Commands

```bash
# Build
xcodebuild build -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Clean build
xcodebuild clean build -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO

# Run tests
xcodebuild test -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ProjectXTests CODE_SIGNING_ALLOWED=NO
```

## Project Structure

```
ProjectX/
├── ProjectXApp.swift          # App entry point, SwiftData container setup
├── ContentView.swift          # Main tab view (Home, Food Bank, Scan, Analysis, Settings)
├── Models/
│   ├── Food.swift             # Food item with nutrition info
│   ├── Tag.swift              # User-defined tags for foods
│   ├── FoodCategory.swift     # Hierarchical categories (main + sub)
│   ├── GroceryTrip.swift      # Shopping trip with purchased items
│   ├── PurchasedItem.swift    # Item linked to a trip and optionally a Food
│   ├── NutritionInfo.swift    # Nutrition data (calories, protein, etc.)
│   ├── NutritionSummary.swift # Aggregated nutrition for a period
│   └── FamilyMember.swift     # Family member profiles for targets
├── Services/
│   ├── AppSettings.swift      # User preferences stored in UserDefaults
│   ├── LLMService.swift       # Protocol for AI services
│   ├── OpenAIService.swift    # OpenAI API implementation
│   ├── ClaudeService.swift    # Anthropic API implementation
│   ├── LLMServiceFactory.swift # Factory for creating LLM service
│   ├── LLMPrompts.swift       # Prompt templates for AI tasks
│   ├── OCRService.swift       # Vision framework text extraction
│   ├── DataExportService.swift # Import/export JSON data
│   ├── DefaultDataManager.swift # Seed default tags
│   └── ScanFlowManager.swift  # Receipt scanning workflow
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift     # Dashboard with trips and nutrition summary
│   │   ├── TripDetailView.swift # Trip details with purchased items, sorting, summary
│   │   ├── ItemEditView.swift # Edit purchased item with AI food matching
│   │   └── AddItemsSheet.swift # AI-powered item addition (photo/text/voice) with review flow
│   ├── FoodBank/
│   │   ├── FoodBankView.swift # Food library with filtering
│   │   └── FoodDetailView.swift # Create/edit food
│   ├── Scan/
│   │   ├── ScanView.swift     # Entry point for scanning
│   │   ├── CameraView.swift   # Camera/photo library wrapper
│   │   ├── ReceiptReviewView.swift # Review extracted items
│   │   ├── ReceiptItemRow.swift # Display extracted item
│   │   ├── ReceiptItemEditSheet.swift # Edit extracted item
│   │   ├── FoodMatchingSheet.swift # Link item to food
│   │   ├── NutritionLabelScanView.swift # Scan nutrition label (multi-photo support)
│   │   ├── NutritionLabelResultView.swift # Display scanned nutrition
│   │   └── MultiPhotoPicker.swift # PHPickerViewController wrapper for multiple photos
│   ├── Analysis/
│   │   └── AnalysisView.swift # Nutrition analysis dashboard
│   ├── Settings/
│   │   ├── SettingsView.swift # Main settings screen
│   │   ├── SettingsSheets.swift # Export/import/nutrition target sheets
│   │   ├── TagCategoryManagementView.swift # Manage tags and view categories
│   │   └── FamilyGuideView.swift # Family nutrition targets setup
│   └── Components/
│       ├── SharedComponents.swift # Reusable UI components
│       ├── TagPicker.swift    # Tag selection with flow layout
│       ├── CategoryPicker.swift # Category hierarchy picker
│       ├── NutritionFieldRow.swift # Nutrition input field
│       ├── TextInputSheet.swift # Generic text input modal
│       └── VoiceInputButton.swift # Speech-to-text button (iOS Speech framework)
├── Theme/
│   └── AppTheme.swift         # Colors, fonts, design tokens
└── Utils/
    └── KeychainHelper.swift   # Secure API key storage
```

## Key Patterns

### SwiftData + SwiftUI Deletion Timing

**Two-part fix required** to prevent "Invalid update: invalid number of items in section" crashes:

**1. Swipe action → confirmation dialog trigger:**
```swift
// In swipe actions, delay setting the delete target
.swipeActions(edge: .trailing, allowsFullSwipe: false) {
    Button(role: .destructive) {
        // Delay to next run loop to let swipe action complete
        DispatchQueue.main.async { itemToDelete = item }
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
```

**2. Confirmation dialog → actual deletion:**
```swift
// In DeleteConfirmationModifier (SharedComponents.swift)
Button("Delete", role: .destructive) {
    guard let toDelete = pendingDelete else { return }
    item = nil
    pendingDelete = nil
    // Delay deletion and wrap in animation to let SwiftUI properly animate removal
    DispatchQueue.main.async {
        withAnimation {
            onDelete(toDelete)
        }
    }
}
```

This prevents crashes where:
1. Swipe action and alert presentation race condition
2. SwiftUI still holds references to deleted objects
3. Cascade deletions (e.g., GroceryTrip → PurchasedItem) conflict with List rendering
4. The List needs animation to properly remove the row before the data is gone

### Shared Components

Extract reusable components to `SharedComponents.swift`:
- `CapsuleBadge` - Tag/category pills
- `FilterChip` - Filter buttons
- `AIProcessingOverlay` - Loading overlay for AI operations
- `ColorPickerButton` - Color selection circles
- `TagEditSheet` - Create/edit tag modal
- `NutritionSummaryRow` - Compact nutrition display
- `DeleteConfirmationModifier` - Reusable delete confirmation

### Batch AI Operations

For batch operations with AI, accumulate errors rather than failing on first error:

```swift
var failedCount = 0
var successCount = 0

for (index, item) in items.enumerated() {
    aiProgressMessage = "Processing \(index + 1)/\(items.count)..."
    do {
        // AI operation
        successCount += 1
    } catch {
        failedCount += 1
    }
}

if failedCount > 0 {
    aiError = "Completed \(successCount) of \(items.count). \(failedCount) failed."
}
```

### Long Image OCR

For tall receipt images (aspect ratio > 3.0, height > 4000px), segment the image with overlap:

```swift
// OCRService.swift
private let maxSegmentHeight: CGFloat = 4000
private let segmentOverlap: CGFloat = 200

// Split image into overlapping segments, OCR each, deduplicate at boundaries
```

## Change Checklist

Before completing any code change, go through this checklist:

1. **Build success** - Run `xcodebuild build -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO`
2. **Test pass** - Run `xcodebuild test -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:ProjectXTests CODE_SIGNING_ALLOWED=NO`
3. **Code simplify** - Review for unnecessary complexity, extract helpers if needed
4. **Code quality** - Check naming, structure, SwiftUI patterns
5. **Docs update** - Update PRD (`docs/plans/2025-01-24-mvp-projectx.md`) if features changed
6. **Update CLAUDE.md** - Add new patterns, files, or gotchas discovered

---

## Style Guidelines

### File Length
- Keep files under 500 lines (unless data/config files)
- Extract sheets and complex components to separate files

### Code Organization
- Group related functionality with `// MARK: -` comments
- Use `private` for internal views and helpers
- Place `@Query` and `@State` at top of view structs

### SwiftUI Patterns
- Use `@Environment(\.modelContext)` for SwiftData access
- Use `@Query` for fetching data with sorting
- Use `@Bindable` for editing SwiftData objects
- Prefer `.sheet(item:)` over `.sheet(isPresented:)` for edit flows

### Async Operations
- Use `.task { }` modifier for view lifecycle async work
- Show loading indicators during AI/network operations
- Provide error feedback via alerts or inline messages

## Known Issues & Fixes

### Trip Deletion Crash
**Issue**: "Invalid update: invalid number of items in section" when deleting trips
**Cause**: SwiftData object deleted while SwiftUI still processing alert dismissal
**Fix**: Wrap `onDelete` in `DispatchQueue.main.async { }` in DeleteConfirmationModifier

### Duplicate Code in Tag Management
**Issue**: ColorPickerButton and TagEditSheet duplicated in TagPicker and TagCategoryManagementView
**Fix**: Extracted to SharedComponents.swift, both views now use shared implementations

## AI Integration

### Supported Providers
- OpenAI (GPT-4o, GPT-4o-mini, GPT-4-turbo)
- Anthropic Claude (claude-3-5-sonnet, claude-3-5-haiku, claude-3-opus)

### AI Features
- Receipt item extraction from images
- Nutrition label extraction from images
- Food category suggestion
- Nutrition estimation by food name
- Food matching (link receipt item to food database)

### API Key Storage
API keys stored securely in Keychain via `KeychainHelper.swift`.

## Data Model Relationships

```
Food ←→ Tag (many-to-many)
GroceryTrip → PurchasedItem (one-to-many)
PurchasedItem → Food (optional, many-to-one)
AppSettings → FamilyMember (embedded array)
```
