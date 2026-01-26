import Foundation
import SwiftData

// Note: Using optional private fields in NutritionInfo for V2 additions
// (sourceRaw, _omega3, _omega6, _vitaminA, etc.) allows automatic lightweight
// migration - new fields get nil which computed properties convert to defaults.
// No explicit VersionedSchema needed for this pattern.
