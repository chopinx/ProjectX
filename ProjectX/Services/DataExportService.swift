import Foundation
import SwiftData

/// Data types that can be exported/imported
enum ExportDataType: String, CaseIterable, Identifiable {
    case foods = "Food Bank"
    case tags = "Tags"
    case trips = "Grocery Trips"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .foods: return "fork.knife"
        case .tags: return "tag.fill"
        case .trips: return "cart.fill"
        }
    }
}

/// Service for exporting and importing app data
final class DataExportService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export

    func exportData(types: Set<ExportDataType>) throws -> Data {
        var exportData = ExportContainer()

        if types.contains(.tags) {
            let tags = try modelContext.fetch(FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)]))
            exportData.tags = tags.map { TagExport(from: $0) }
        }

        if types.contains(.foods) {
            let foods = try modelContext.fetch(FetchDescriptor<Food>(sortBy: [SortDescriptor(\.name)]))
            exportData.foods = foods.map { FoodExport(from: $0) }
        }

        if types.contains(.trips) {
            let trips = try modelContext.fetch(FetchDescriptor<GroceryTrip>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
            exportData.trips = trips.map { TripExport(from: $0) }
        }

        exportData.exportDate = Date()
        exportData.version = "1.0"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(exportData)
    }

    // MARK: - Import

    func importData(from data: Data, types: Set<ExportDataType>) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let container = try decoder.decode(ExportContainer.self, from: data)

        var result = ImportResult()

        if types.contains(.tags), let tags = container.tags {
            result.tagsImported = importTags(tags)
        }

        if types.contains(.foods), let foods = container.foods {
            result.foodsImported = importFoods(foods)
        }

        if types.contains(.trips), let trips = container.trips {
            result.tripsImported = importTrips(trips)
        }

        try modelContext.save()
        return result
    }

    private func importTags(_ tags: [TagExport]) -> Int {
        let existingTags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        let existingByName = Dictionary(uniqueKeysWithValues: existingTags.map { ($0.name.lowercased(), $0) })

        var imported = 0
        for tagData in tags {
            if let existing = existingByName[tagData.name.lowercased()] {
                // Replace existing
                existing.colorHex = tagData.colorHex
            } else {
                // Create new
                let tag = Tag(name: tagData.name, colorHex: tagData.colorHex)
                modelContext.insert(tag)
            }
            imported += 1
        }
        return imported
    }

    private func importFoods(_ foods: [FoodExport]) -> Int {
        let existingFoods = (try? modelContext.fetch(FetchDescriptor<Food>())) ?? []
        let existingByName = Dictionary(uniqueKeysWithValues: existingFoods.map { ($0.name.lowercased(), $0) })

        // Get all tags for linking
        let allTags = (try? modelContext.fetch(FetchDescriptor<Tag>())) ?? []
        let tagsByName = Dictionary(uniqueKeysWithValues: allTags.map { ($0.name.lowercased(), $0) })

        var imported = 0
        for foodData in foods {
            let linkedTags = foodData.tagNames.compactMap { tagsByName[$0.lowercased()] }

            if let existing = existingByName[foodData.name.lowercased()] {
                // Replace existing
                existing.categoryRaw = foodData.categoryRaw
                existing.tags = linkedTags
                existing.updatedAt = Date()
                if let nutritionData = foodData.nutrition {
                    if let nutrition = existing.nutrition {
                        nutrition.calories = nutritionData.calories
                        nutrition.protein = nutritionData.protein
                        nutrition.carbohydrates = nutritionData.carbohydrates
                        nutrition.fat = nutritionData.fat
                        nutrition.saturatedFat = nutritionData.saturatedFat
                        nutrition.sugar = nutritionData.sugar
                        nutrition.fiber = nutritionData.fiber
                        nutrition.sodium = nutritionData.sodium
                    } else {
                        existing.nutrition = NutritionInfo(
                            calories: nutritionData.calories,
                            protein: nutritionData.protein,
                            carbohydrates: nutritionData.carbohydrates,
                            fat: nutritionData.fat,
                            saturatedFat: nutritionData.saturatedFat,
                            sugar: nutritionData.sugar,
                            fiber: nutritionData.fiber,
                            sodium: nutritionData.sodium
                        )
                    }
                }
            } else {
                // Create new
                let nutrition = foodData.nutrition.map {
                    NutritionInfo(
                        calories: $0.calories,
                        protein: $0.protein,
                        carbohydrates: $0.carbohydrates,
                        fat: $0.fat,
                        saturatedFat: $0.saturatedFat,
                        sugar: $0.sugar,
                        fiber: $0.fiber,
                        sodium: $0.sodium
                    )
                }
                let food = Food(
                    name: foodData.name,
                    category: FoodCategory(rawValue: foodData.categoryRaw),
                    nutrition: nutrition,
                    tags: linkedTags
                )
                modelContext.insert(food)
            }
            imported += 1
        }
        return imported
    }

    private func importTrips(_ trips: [TripExport]) -> Int {
        let existingTrips = (try? modelContext.fetch(FetchDescriptor<GroceryTrip>())) ?? []
        let existingIds = Set(existingTrips.map { $0.id })

        // Get all foods for linking
        let allFoods = (try? modelContext.fetch(FetchDescriptor<Food>())) ?? []
        let foodsByName = Dictionary(uniqueKeysWithValues: allFoods.map { ($0.name.lowercased(), $0) })

        var imported = 0
        for tripData in trips {
            if !existingIds.contains(tripData.id) {
                let trip = GroceryTrip(
                    id: tripData.id,
                    date: tripData.date,
                    storeName: tripData.storeName
                )
                modelContext.insert(trip)

                for itemData in tripData.items {
                    let linkedFood = itemData.foodName.flatMap { foodsByName[$0.lowercased()] }
                    let item = PurchasedItem(
                        id: itemData.id,
                        name: itemData.name,
                        quantity: itemData.quantity,
                        price: itemData.price,
                        food: linkedFood,
                        isSkipped: itemData.isSkipped
                    )
                    item.trip = trip
                    trip.items.append(item)
                }
                imported += 1
            }
        }
        return imported
    }

    // MARK: - Preview Available Data

    func previewImport(from data: Data) throws -> ImportPreview {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let container = try decoder.decode(ExportContainer.self, from: data)

        return ImportPreview(
            tagsCount: container.tags?.count ?? 0,
            foodsCount: container.foods?.count ?? 0,
            tripsCount: container.trips?.count ?? 0,
            exportDate: container.exportDate
        )
    }
}

// MARK: - Export Data Structures

struct ExportContainer: Codable {
    var version: String = "1.0"
    var exportDate: Date?
    var tags: [TagExport]?
    var foods: [FoodExport]?
    var trips: [TripExport]?
}

struct TagExport: Codable {
    let name: String
    let colorHex: String

    init(from tag: Tag) {
        self.name = tag.name
        self.colorHex = tag.colorHex
    }
}

struct NutritionExport: Codable {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let saturatedFat: Double
    let sugar: Double
    let fiber: Double
    let sodium: Double

    init(from info: NutritionInfo) {
        self.calories = info.calories
        self.protein = info.protein
        self.carbohydrates = info.carbohydrates
        self.fat = info.fat
        self.saturatedFat = info.saturatedFat
        self.sugar = info.sugar
        self.fiber = info.fiber
        self.sodium = info.sodium
    }
}

struct FoodExport: Codable {
    let name: String
    let categoryRaw: String
    let nutrition: NutritionExport?
    let tagNames: [String]

    init(from food: Food) {
        self.name = food.name
        self.categoryRaw = food.categoryRaw
        self.nutrition = food.nutrition.map { NutritionExport(from: $0) }
        self.tagNames = food.tags.map { $0.name }
    }
}

struct PurchasedItemExport: Codable {
    let id: UUID
    let name: String
    let quantity: Double
    let price: Double
    let foodName: String?
    let isSkipped: Bool

    init(from item: PurchasedItem) {
        self.id = item.id
        self.name = item.name
        self.quantity = item.quantity
        self.price = item.price
        self.foodName = item.food?.name
        self.isSkipped = item.isSkipped
    }
}

struct TripExport: Codable {
    let id: UUID
    let date: Date
    let storeName: String?
    let items: [PurchasedItemExport]

    init(from trip: GroceryTrip) {
        self.id = trip.id
        self.date = trip.date
        self.storeName = trip.storeName
        self.items = trip.items.map { PurchasedItemExport(from: $0) }
    }
}

// MARK: - Import Result

struct ImportResult {
    var tagsImported: Int = 0
    var foodsImported: Int = 0
    var tripsImported: Int = 0

    var totalImported: Int { tagsImported + foodsImported + tripsImported }

    var summary: String {
        var parts: [String] = []
        if tagsImported > 0 { parts.append("\(tagsImported) tags") }
        if foodsImported > 0 { parts.append("\(foodsImported) foods") }
        if tripsImported > 0 { parts.append("\(tripsImported) trips") }
        return parts.isEmpty ? "No new data imported" : "Imported: " + parts.joined(separator: ", ")
    }
}

struct ImportPreview {
    let tagsCount: Int
    let foodsCount: Int
    let tripsCount: Int
    let exportDate: Date?

    var hasData: Bool { tagsCount > 0 || foodsCount > 0 || tripsCount > 0 }
}
