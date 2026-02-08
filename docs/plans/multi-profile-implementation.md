# Multi-Profile Implementation Plan

## Overview

Add multi-profile support where each profile has isolated consumption data (meals, trips), family member settings, and nutrition targets. General settings (LLM config, API keys) and the Food Bank are shared across all profiles.

**Key Principle:** Profiles enable multiple users (family members) to track their individual consumption while sharing the same Food Bank.

## Architecture

```
Shared Data (App-wide)
├── Food Bank (foods)
├── Tags
├── Custom Subcategories
└── General Settings (LLM provider, API keys, filter settings)

Profile-Specific Data
├── GroceryTrips → PurchasedItems
├── Meals → MealItems
├── FamilyMembers
├── NutritionTargets
└── Profile metadata (name, icon, color)
```

## Data Model Changes

### New Model: Profile

| Field | Type | Description |
|-------|------|-------------|
| id | UUID | Unique identifier |
| name | String | Profile name (e.g., "Dad", "Mom", "Kids") |
| iconName | String | SF Symbol name for profile icon |
| colorHex | String | Profile accent color (hex) |
| isDefault | Bool | Whether this is the default profile |
| createdAt | Date | Creation timestamp |

### Relationship Changes

```
Profile (new)
├── GroceryTrips (one-to-many) - Add profile: Profile? to GroceryTrip
├── Meals (one-to-many) - Add profile: Profile? to Meal
└── (via UserDefaults) familyMembers, nutritionTarget

Food Bank (shared)
├── Food (no profile relationship)
├── Tag (no profile relationship)
└── CustomSubcategory (no profile relationship)
```

### AppSettings Changes

Move profile-specific settings to profile-keyed storage:
- `familyMembers_{profileId}` - Family members per profile
- `nutritionTarget_{profileId}` - Nutrition targets per profile
- `hasCompletedFamilyGuide_{profileId}` - Guide completion per profile
- `activeProfileId` - Currently selected profile

Keep global settings unchanged:
- LLM provider, API keys
- Model selection
- `filterBabyFood`

## New Files to Create

| File | Purpose |
|------|---------|
| `Models/Profile.swift` | Profile SwiftData model |
| `Views/Settings/ProfilesView.swift` | Profile management UI |
| `Views/Settings/ProfileEditorSheet.swift` | Create/edit profile |
| `Views/Components/ProfileSwitcher.swift` | Quick profile switch UI |

## Files to Modify

| File | Changes |
|------|---------|
| `Models/GroceryTrip.swift` | Add `profile: Profile?` relationship |
| `Models/Meal.swift` | Add `profile: Profile?` relationship |
| `Services/AppSettings.swift` | Profile-keyed settings, active profile |
| `ProjectXApp.swift` | Add Profile.self to schema |
| `ContentView.swift` | Add profile switcher in tab bar |
| `Views/Home/HomeView.swift` | Filter trips by active profile |
| `Views/Meals/MealsView.swift` | Filter meals by active profile |
| `Views/Analysis/AnalysisView.swift` | Filter by active profile |
| `Views/Settings/SettingsView.swift` | Add Profiles section |
| `Views/Settings/FamilyGuideView.swift` | Use profile-specific family members |

## Implementation Tasks

### Task 1: Profile Model
Create `Models/Profile.swift`:
- Profile SwiftData model with id, name, iconName, colorHex, isDefault
- Default icons: person.fill, figure.stand, figure.2.arms.open, etc.
- Default colors: blue, green, purple, orange, pink

### Task 2: Update Existing Models
Modify GroceryTrip and Meal:
- Add optional `profile: Profile?` relationship
- Update cascade delete rules

### Task 3: Profile-Keyed Settings
Modify AppSettings:
- Add `activeProfileId: UUID?`
- Create profile-specific getters/setters for familyMembers, nutritionTarget
- Add `setActiveProfile(id:)` method
- Migration: create default profile if none exists

### Task 4: Profile Management UI
Create ProfilesView and ProfileEditorSheet:
- List profiles with icons and colors
- Add/edit/delete profiles
- Set default profile
- Cannot delete the last profile

### Task 5: Profile Switcher
Create ProfileSwitcher component:
- Compact menu in navigation bar or tab bar area
- Shows active profile name/icon
- Tap to switch profiles quickly

### Task 6: Filter Views by Profile
Update HomeView, MealsView, AnalysisView:
- Filter queries by activeProfile
- Pass profile to new trip/meal creation

### Task 7: Schema Migration
Update ProjectXApp:
- Add Profile.self to schema
- Handle migration for existing data (assign to default profile)

### Task 8: Integration
- Update FamilyGuideView to use profile-specific settings
- Update NutritionSummary to filter by profile
- Test all flows with multiple profiles

## UI Changes

### Tab Bar / Navigation
```
┌─────────────────────────────────────┐
│ [Profile Icon ▼]  ProjectX          │  <- Profile switcher
├─────────────────────────────────────┤
│                                     │
│          Content Area               │
│                                     │
├─────────────────────────────────────┤
│ Trips │ Meals │ Foods │ Analysis │ ⚙ │
└─────────────────────────────────────┘
```

### Settings Screen
```
Settings
├── Profiles        <- New section
│   ├── [Active: Dad]
│   ├── Mom
│   └── [+ Add Profile]
├── Nutrition Guide  <- Now profile-specific
├── LLM Provider     <- Shared
├── API Keys         <- Shared
└── Data Management  <- Includes profile export
```

### Profile Switcher Dropdown
```
┌──────────────────┐
│ 👨 Dad      ✓    │  <- Active
│ 👩 Mom           │
│ 👧 Kids          │
├──────────────────┤
│ ⚙ Manage...      │
└──────────────────┘
```

## Data Migration

For existing users upgrading:
1. Create a default profile named "Default"
2. Assign all existing trips and meals to default profile
3. Copy existing familyMembers and nutritionTarget to default profile
4. Set default profile as active

## Key Differences: Shared vs Profile-Specific

| Data | Scope | Reason |
|------|-------|--------|
| Food Bank | Shared | Same household buys same foods |
| Tags | Shared | Food categorization is universal |
| Categories | Shared | Standard food taxonomy |
| LLM Config | Shared | Single API key per household |
| Trips | Profile | Different people shop differently |
| Meals | Profile | Individual consumption tracking |
| Family Guide | Profile | Different household compositions |
| Targets | Profile | Different nutritional needs |

## Verification

1. **Build**: `xcodebuild build -scheme ProjectX -destination 'platform=iOS Simulator,name=iPhone 17'`
2. **Test**:
   - Create multiple profiles
   - Add trips/meals to different profiles
   - Verify isolation (profile A trips don't appear in profile B)
   - Verify Food Bank is shared
   - Verify settings isolation
   - Switch profiles and verify correct data shown
3. **Migration**:
   - Test upgrade from non-profile version
   - Verify existing data assigned to default profile
