import Foundation
import SwiftData

enum ExportDataType: String, CaseIterable, Identifiable {
    case foods = "Food Bank", tags = "Tags", trips = "Grocery Trips", meals = "Meals"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .foods: "fork.knife"
        case .tags: "tag.fill"
        case .trips: "cart.fill"
        case .meals: "fork.knife.circle"
        }
    }
}

final class DataExportService {
    private let ctx: ModelContext
    private var activeProfileId: UUID?

    init(modelContext: ModelContext, profileId: UUID? = nil) {
        self.ctx = modelContext
        self.activeProfileId = profileId
    }

    // MARK: - Export (filtered by profile for trips/meals)

    func exportData(types: Set<ExportDataType>) throws -> Data {
        var export = ExportContainer()
        if types.contains(.tags) { export.tags = try fetch(Tag.self, sort: \.name).map { TagExport(from: $0) } }
        if types.contains(.foods) { export.foods = try fetch(Food.self, sort: \.name).map { FoodExport(from: $0) } }
        if types.contains(.trips) {
            let allTrips = try fetch(GroceryTrip.self, sort: \.date, reverse: true)
            let filteredTrips = filterByProfile(allTrips)
            export.trips = filteredTrips.map { TripExport(from: $0) }
        }
        if types.contains(.meals) {
            let allMeals = try fetch(Meal.self, sort: \.date, reverse: true)
            let filteredMeals = filterByProfile(allMeals)
            export.meals = filteredMeals.map { MealExport(from: $0) }
        }
        export.exportDate = Date()
        export.profileId = activeProfileId
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    private func filterByProfile<T: PersistentModel>(_ items: [T]) -> [T] {
        guard let profileId = activeProfileId else { return items }
        return items.filter { item in
            if let trip = item as? GroceryTrip {
                return trip.profile?.id == profileId
            } else if let meal = item as? Meal {
                return meal.profile?.id == profileId
            }
            return true
        }
    }

    // MARK: - Import (assigns to current profile)

    func importData(from data: Data, types: Set<ExportDataType>) throws -> ImportResult {
        let container = try decode(data)
        var result = ImportResult()
        if types.contains(.tags), let tags = container.tags { result.tagsImported = importTags(tags) }
        if types.contains(.foods), let foods = container.foods { result.foodsImported = importFoods(foods) }
        if types.contains(.trips), let trips = container.trips { result.tripsImported = importTrips(trips) }
        if types.contains(.meals), let meals = container.meals { result.mealsImported = importMeals(meals) }
        try ctx.save()
        return result
    }

    func previewImport(from data: Data) throws -> ImportPreview {
        let c = try decode(data)
        return ImportPreview(
            tagsCount: c.tags?.count ?? 0,
            foodsCount: c.foods?.count ?? 0,
            tripsCount: c.trips?.count ?? 0,
            mealsCount: c.meals?.count ?? 0,
            exportDate: c.exportDate,
            profileId: c.profileId
        )
    }

    // MARK: - Helpers

    private func fetch<T: PersistentModel>(_ type: T.Type, sort: KeyPath<T, some Comparable>, reverse: Bool = false) throws -> [T] {
        try ctx.fetch(FetchDescriptor<T>(sortBy: [SortDescriptor(sort, order: reverse ? .reverse : .forward)]))
    }

    private func decode(_ data: Data) throws -> ExportContainer {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(ExportContainer.self, from: data)
    }

    private func importTags(_ tags: [TagExport]) -> Int {
        let existing = Dictionary(uniqueKeysWithValues: ((try? ctx.fetch(FetchDescriptor<Tag>())) ?? []).map { ($0.name.lowercased(), $0) })
        for t in tags {
            if let e = existing[t.name.lowercased()] { e.colorHex = t.colorHex }
            else { ctx.insert(Tag(name: t.name, colorHex: t.colorHex)) }
        }
        return tags.count
    }

    private func importFoods(_ foods: [FoodExport]) -> Int {
        let existing = Dictionary(uniqueKeysWithValues: ((try? ctx.fetch(FetchDescriptor<Food>())) ?? []).map { ($0.name.lowercased(), $0) })
        let tagsByName = Dictionary(uniqueKeysWithValues: ((try? ctx.fetch(FetchDescriptor<Tag>())) ?? []).map { ($0.name.lowercased(), $0) })

        for f in foods {
            let linkedTags = f.tagNames.compactMap { tagsByName[$0.lowercased()] }
            if let e = existing[f.name.lowercased()] {
                e.categoryRaw = f.categoryRaw
                e.tags = linkedTags
                e.isPantryStaple = f.isPantryStaple ?? false
                e.updatedAt = Date()
                if let n = f.nutrition {
                    if let en = e.nutrition { en.copyValues(from: n.toNutritionInfo()) }
                    else { e.nutrition = n.toNutritionInfo() }
                }
            } else {
                ctx.insert(Food(name: f.name, category: FoodCategory(rawValue: f.categoryRaw), nutrition: f.nutrition?.toNutritionInfo(),
                                tags: linkedTags, isUserCreated: f.isUserCreated ?? true, isPantryStaple: f.isPantryStaple ?? false))
            }
        }
        return foods.count
    }

    private func importTrips(_ trips: [TripExport]) -> Int {
        let existingIds = Set(((try? ctx.fetch(FetchDescriptor<GroceryTrip>())) ?? []).map(\.id))
        let foodsByName = Dictionary(uniqueKeysWithValues: ((try? ctx.fetch(FetchDescriptor<Food>())) ?? []).map { ($0.name.lowercased(), $0) })
        let profile = fetchActiveProfile()

        var imported = 0
        for t in trips where !existingIds.contains(t.id) {
            let trip = GroceryTrip(id: t.id, date: t.date, storeName: t.storeName)
            trip.profile = profile
            ctx.insert(trip)
            for i in t.items {
                let item = PurchasedItem(id: i.id, name: i.name, quantity: i.quantity, price: i.price,
                                         food: i.foodName.flatMap { foodsByName[$0.lowercased()] }, isSkipped: i.isSkipped)
                item.trip = trip
                trip.items.append(item)
            }
            imported += 1
        }
        return imported
    }

    private func importMeals(_ meals: [MealExport]) -> Int {
        let existingIds = Set(((try? ctx.fetch(FetchDescriptor<Meal>())) ?? []).map(\.id))
        let foodsByName = Dictionary(uniqueKeysWithValues: ((try? ctx.fetch(FetchDescriptor<Food>())) ?? []).map { ($0.name.lowercased(), $0) })
        let profile = fetchActiveProfile()

        var imported = 0
        for m in meals where !existingIds.contains(m.id) {
            let mealType = MealType(rawValue: m.mealType) ?? .snack
            let meal = Meal(id: m.id, date: m.date, mealType: mealType, notes: m.notes)
            meal.profile = profile
            ctx.insert(meal)
            for i in m.items {
                let item = MealItem(id: i.id, name: i.name, quantity: i.quantity,
                                    food: i.foodName.flatMap { foodsByName[$0.lowercased()] }, isSkipped: i.isSkipped)
                item.meal = meal
                meal.items.append(item)
            }
            imported += 1
        }
        return imported
    }

    private func fetchActiveProfile() -> Profile? {
        guard let profileId = activeProfileId else { return nil }
        let descriptor = FetchDescriptor<Profile>()
        return (try? ctx.fetch(descriptor))?.first { $0.id == profileId }
    }
}

// MARK: - Export Structures

struct ExportContainer: Codable {
    var version = "2.0"
    var exportDate: Date?
    var profileId: UUID?
    var tags: [TagExport]?
    var foods: [FoodExport]?
    var trips: [TripExport]?
    var meals: [MealExport]?
}

struct TagExport: Codable {
    let name, colorHex: String
    init(from t: Tag) { name = t.name; colorHex = t.colorHex }
}

struct NutritionExport: Codable {
    // Original fields (required)
    let calories, protein, carbohydrates, fat, saturatedFat, sugar, fiber, sodium: Double
    // New fields (optional for backward compatibility with old exports)
    let source: String?
    let omega3, omega6: Double?
    let vitaminA, vitaminC, vitaminD, calcium, iron, potassium: Double?

    init(from n: NutritionInfo) {
        source = n.source.rawValue; calories = n.calories; protein = n.protein; carbohydrates = n.carbohydrates
        fat = n.fat; saturatedFat = n.saturatedFat; omega3 = n.omega3; omega6 = n.omega6
        sugar = n.sugar; fiber = n.fiber; sodium = n.sodium
        vitaminA = n.vitaminA; vitaminC = n.vitaminC; vitaminD = n.vitaminD
        calcium = n.calcium; iron = n.iron; potassium = n.potassium
    }

    func toNutritionInfo() -> NutritionInfo {
        NutritionInfo(source: source.flatMap { NutritionSource(rawValue: $0) } ?? .manual,
                      calories: calories, protein: protein, carbohydrates: carbohydrates,
                      fat: fat, saturatedFat: saturatedFat, omega3: omega3 ?? 0, omega6: omega6 ?? 0,
                      sugar: sugar, fiber: fiber, sodium: sodium,
                      vitaminA: vitaminA ?? 0, vitaminC: vitaminC ?? 0, vitaminD: vitaminD ?? 0,
                      calcium: calcium ?? 0, iron: iron ?? 0, potassium: potassium ?? 0)
    }
}

struct FoodExport: Codable {
    let name, categoryRaw: String
    let nutrition: NutritionExport?
    let tagNames: [String]
    let isPantryStaple, isUserCreated: Bool?

    init(from f: Food) {
        name = f.name; categoryRaw = f.categoryRaw; nutrition = f.nutrition.map { NutritionExport(from: $0) }
        tagNames = f.tags.map(\.name); isPantryStaple = f.isPantryStaple; isUserCreated = f.isUserCreated
    }
}

struct PurchasedItemExport: Codable {
    let id: UUID, name: String, quantity: Double, price: Double, foodName: String?, isSkipped: Bool
    init(from i: PurchasedItem) {
        id = i.id; name = i.name; quantity = i.quantity; price = i.price; foodName = i.food?.name; isSkipped = i.isSkipped
    }
}

struct TripExport: Codable {
    let id: UUID, date: Date, storeName: String?, items: [PurchasedItemExport]
    init(from t: GroceryTrip) { id = t.id; date = t.date; storeName = t.storeName; items = t.items.map { PurchasedItemExport(from: $0) } }
}

struct MealItemExport: Codable {
    let id: UUID, name: String, quantity: Double, foodName: String?, isSkipped: Bool
    init(from i: MealItem) {
        id = i.id; name = i.name; quantity = i.quantity; foodName = i.food?.name; isSkipped = i.isSkipped
    }
}

struct MealExport: Codable {
    let id: UUID, date: Date, mealType: String, notes: String?, items: [MealItemExport]
    init(from m: Meal) {
        id = m.id; date = m.date; mealType = m.mealType.rawValue; notes = m.notes
        items = m.items.map { MealItemExport(from: $0) }
    }
}

// MARK: - Import Result

struct ImportResult {
    var tagsImported = 0, foodsImported = 0, tripsImported = 0, mealsImported = 0
    var totalImported: Int { tagsImported + foodsImported + tripsImported + mealsImported }
    var summary: String {
        let parts = [(tagsImported, "tags"), (foodsImported, "foods"), (tripsImported, "trips"), (mealsImported, "meals")].filter { $0.0 > 0 }.map { "\($0.0) \($0.1)" }
        return parts.isEmpty ? "No new data imported" : "Imported: " + parts.joined(separator: ", ")
    }
}

struct ImportPreview {
    let tagsCount, foodsCount, tripsCount, mealsCount: Int
    let exportDate: Date?
    let profileId: UUID?
    var hasData: Bool { tagsCount > 0 || foodsCount > 0 || tripsCount > 0 || mealsCount > 0 }
}
