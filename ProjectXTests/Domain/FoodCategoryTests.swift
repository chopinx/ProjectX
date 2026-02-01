import XCTest
@testable import ProjectX

final class FoodCategoryTests: XCTestCase {

    // MARK: - Init from String

    func testInitFromString_MainCategory() {
        let category = FoodCategory(fromString: "proteins")
        XCTAssertEqual(category.main, .proteins)
        XCTAssertNil(category.sub)
    }

    func testInitFromString_MainCategoryDisplayName() {
        let category = FoodCategory(fromString: "Dairy & Alternatives")
        XCTAssertEqual(category.main, .dairy)
    }

    func testInitFromString_SubcategoryRawValue() {
        let category = FoodCategory(fromString: "leanMeat")
        XCTAssertEqual(category.main, .proteins)
        XCTAssertEqual(category.sub, .leanMeat)
    }

    func testInitFromString_SubcategoryDisplayName() {
        let category = FoodCategory(fromString: "Leafy Greens")
        XCTAssertEqual(category.main, .vegetables)
        XCTAssertEqual(category.sub, .leafyGreens)
    }

    func testInitFromString_CommonFoodMappings() {
        XCTAssertEqual(FoodCategory(fromString: "chicken").sub, .leanMeat)
        XCTAssertEqual(FoodCategory(fromString: "salmon").sub, .seafood)
        XCTAssertEqual(FoodCategory(fromString: "spinach").sub, .leafyGreens)
        XCTAssertEqual(FoodCategory(fromString: "banana").sub, .tropicalFruits)
        XCTAssertEqual(FoodCategory(fromString: "yogurt").sub, .yogurtFermented)
        XCTAssertEqual(FoodCategory(fromString: "pasta").sub, .pastaNoodles)
    }

    func testInitFromString_UnknownDefaultsToOther() {
        let category = FoodCategory(fromString: "unknown food item xyz")
        XCTAssertEqual(category.main, .other)
        XCTAssertNil(category.sub)
    }

    func testInitFromString_CaseInsensitive() {
        XCTAssertEqual(FoodCategory(fromString: "PROTEINS").main, .proteins)
        XCTAssertEqual(FoodCategory(fromString: "Proteins").main, .proteins)
        XCTAssertEqual(FoodCategory(fromString: "CHICKEN").sub, .leanMeat)
    }

    // MARK: - Init from Raw Value

    func testInitFromRawValue_MainOnly() {
        let category = FoodCategory(rawValue: "proteins")
        XCTAssertEqual(category.main, .proteins)
        XCTAssertNil(category.sub)
    }

    func testInitFromRawValue_WithSubcategory() {
        let category = FoodCategory(rawValue: "proteins/leanMeat")
        XCTAssertEqual(category.main, .proteins)
        XCTAssertEqual(category.sub, .leanMeat)
    }

    func testInitFromRawValue_WithCustomSubcategory() {
        let category = FoodCategory(rawValue: "proteins/custom:Wild Game")
        XCTAssertEqual(category.main, .proteins)
        XCTAssertNil(category.sub)
        XCTAssertEqual(category.customSub, "Wild Game")
    }

    func testInitFromRawValue_InvalidMainDefaultsToOther() {
        let category = FoodCategory(rawValue: "invalid")
        XCTAssertEqual(category.main, .other)
    }

    // MARK: - Raw Value Round Trip

    func testRawValue_MainOnly() {
        let category = FoodCategory(main: .vegetables)
        XCTAssertEqual(category.rawValue, "vegetables")
    }

    func testRawValue_WithSubcategory() {
        let category = FoodCategory(main: .vegetables, sub: .leafyGreens)
        XCTAssertEqual(category.rawValue, "vegetables/leafyGreens")
    }

    func testRawValue_WithCustomSubcategory() {
        let category = FoodCategory(main: .vegetables, customSub: "Root Vegetables")
        XCTAssertEqual(category.rawValue, "vegetables/custom:Root Vegetables")
    }

    func testRawValue_RoundTrip() {
        let original = FoodCategory(main: .grains, sub: .wholeGrains)
        let roundTripped = FoodCategory(rawValue: original.rawValue)

        XCTAssertEqual(roundTripped.main, original.main)
        XCTAssertEqual(roundTripped.sub, original.sub)
    }

    // MARK: - Display Properties

    func testDisplayName_MainOnly() {
        let category = FoodCategory(main: .proteins)
        XCTAssertEqual(category.displayName, "Proteins")
    }

    func testDisplayName_WithSubcategory() {
        let category = FoodCategory(main: .proteins, sub: .seafood)
        XCTAssertEqual(category.displayName, "Seafood")
    }

    func testDisplayName_WithCustomSubcategory() {
        let category = FoodCategory(main: .proteins, customSub: "Wild Game")
        XCTAssertEqual(category.displayName, "Wild Game")
    }

    func testFullPath_MainOnly() {
        let category = FoodCategory(main: .proteins)
        XCTAssertEqual(category.fullPath, "Proteins")
    }

    func testFullPath_WithSubcategory() {
        let category = FoodCategory(main: .proteins, sub: .seafood)
        XCTAssertEqual(category.fullPath, "Proteins > Seafood")
    }

    func testFullPath_WithCustomSubcategory() {
        let category = FoodCategory(main: .proteins, customSub: "Wild Game")
        XCTAssertEqual(category.fullPath, "Proteins > Wild Game")
    }

    // MARK: - Subcategory Parent Relationship

    func testSubcategoryParent_ProteinsGroup() {
        XCTAssertEqual(FoodSubcategory.leanMeat.parent, .proteins)
        XCTAssertEqual(FoodSubcategory.seafood.parent, .proteins)
        XCTAssertEqual(FoodSubcategory.eggs.parent, .proteins)
    }

    func testSubcategoryParent_VegetablesGroup() {
        XCTAssertEqual(FoodSubcategory.leafyGreens.parent, .vegetables)
        XCTAssertEqual(FoodSubcategory.cruciferous.parent, .vegetables)
        XCTAssertEqual(FoodSubcategory.starchyVegetables.parent, .vegetables)
    }

    func testMainCategory_SubcategoriesProperty() {
        let proteinSubs = FoodMainCategory.proteins.subcategories
        XCTAssertTrue(proteinSubs.contains(.leanMeat))
        XCTAssertTrue(proteinSubs.contains(.seafood))
        XCTAssertFalse(proteinSubs.contains(.leafyGreens))
    }

    // MARK: - Has Subcategory

    func testHasSubcategory_False() {
        let category = FoodCategory(main: .proteins)
        XCTAssertFalse(category.hasSubcategory)
    }

    func testHasSubcategory_TrueWithSub() {
        let category = FoodCategory(main: .proteins, sub: .leanMeat)
        XCTAssertTrue(category.hasSubcategory)
    }

    func testHasSubcategory_TrueWithCustomSub() {
        let category = FoodCategory(main: .proteins, customSub: "Wild Game")
        XCTAssertTrue(category.hasSubcategory)
    }

    // MARK: - Static Other

    func testStaticOther() {
        let other = FoodCategory.other
        XCTAssertEqual(other.main, .other)
        XCTAssertNil(other.sub)
        XCTAssertNil(other.customSub)
    }
}
