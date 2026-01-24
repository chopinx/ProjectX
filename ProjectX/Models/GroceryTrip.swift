import Foundation
import SwiftData

@Model
final class GroceryTrip {
    @Attribute(.unique) var id: UUID
    var date: Date
    var storeName: String?
    @Relationship(deleteRule: .cascade, inverse: \PurchasedItem.trip) var items: [PurchasedItem]
    var createdAt: Date
    var updatedAt: Date

    var totalSpent: Double {
        items.reduce(0) { $0 + $1.price }
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        storeName: String? = nil,
        items: [PurchasedItem] = []
    ) {
        self.id = id
        self.date = date
        self.storeName = storeName
        self.items = items
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
