import Foundation
import SwiftUI
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var colorHex: String
    var createdAt: Date

    @Relationship(inverse: \Food.tags) var foods: [Food] = []

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(id: UUID = UUID(), name: String, colorHex: String = "007AFF") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
    }

    // Preset tag colors
    static let presetColors: [(name: String, hex: String)] = [
        ("Blue", "007AFF"),
        ("Green", "34C759"),
        ("Red", "FF3B30"),
        ("Orange", "FF9500"),
        ("Purple", "AF52DE"),
        ("Pink", "FF2D55"),
        ("Teal", "5AC8FA"),
        ("Yellow", "FFCC00"),
        ("Gray", "8E8E93")
    ]

    // Default tags for new users
    static let defaultTags: [(name: String, colorHex: String)] = [
        ("Organic", "34C759"),       // Green
        ("Local", "5AC8FA"),         // Teal
        ("High Protein", "FF9500"),  // Orange
        ("Low Carb", "007AFF"),      // Blue
        ("Plant-Based", "34C759"),   // Green
        ("Whole Food", "34C759"),    // Green
        ("Processed", "8E8E93"),     // Gray
        ("Red Meat", "FF3B30"),      // Red
        ("High Fiber", "AF52DE"),    // Purple
        ("Omega-3 Rich", "5AC8FA"),  // Teal
        ("Low Sodium", "007AFF"),    // Blue
        ("Sugar-Free", "FFCC00")     // Yellow
    ]
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "007AFF"
        }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
