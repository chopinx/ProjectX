import Foundation
import SwiftData
import SwiftUI

@Model
final class Profile {
    @Attribute(.unique) var id: UUID
    var name: String
    var iconName: String
    var colorHex: String
    var isDefault: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \GroceryTrip.profile) var trips: [GroceryTrip]
    @Relationship(deleteRule: .nullify, inverse: \Meal.profile) var meals: [Meal]

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    init(
        id: UUID = UUID(),
        name: String = "Default",
        iconName: String = "person.fill",
        colorHex: String = "007AFF",
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.createdAt = Date()
        self.trips = []
        self.meals = []
    }

    static let availableIcons = [
        "person.fill", "figure.stand", "figure.wave",
        "face.smiling", "star.fill", "heart.fill", "leaf.fill"
    ]

    static let availableColors: [(name: String, hex: String)] = [
        ("Blue", "007AFF"), ("Green", "34C759"), ("Purple", "AF52DE"),
        ("Orange", "FF9500"), ("Pink", "FF2D55"), ("Teal", "5AC8FA")
    ]
}
