import Foundation

/// Shared prompts for LLM services
/// All prompts enforce strict JSON-only output for reliable parsing
enum LLMPrompts {

    // MARK: - Dynamic Category Generation

    /// Generate category list from FoodMainCategory enum
    private static var categoryList: String {
        FoodMainCategory.allCases.map(\.rawValue).joined(separator: "/")
    }

    /// Generate full category and subcategory mapping from enums
    private static var categorySubcategoryMapping: String {
        FoodMainCategory.allCases.map { main in
            let subs = main.subcategories.map(\.rawValue).joined(separator: ", ")
            return "- \(main.rawValue): \(subs.isEmpty ? "(no subcategories)" : subs)"
        }.joined(separator: "\n        ")
    }

    // MARK: - Strict Output Instructions (appended to all prompts)

    private static let strictOutputRules = """

        CRITICAL OUTPUT REQUIREMENTS:
        - Output ONLY the JSON object/array, nothing else
        - Do NOT wrap in markdown code blocks (no ```)
        - Do NOT include any text before or after the JSON
        - Do NOT include comments or explanations
        - Do NOT say "Here is" or any introduction
        - Ensure valid JSON syntax (proper quotes, commas, brackets)
        - Use numbers without quotes for numeric fields
        - NEVER use null for numeric fields - use 0 instead
        - Start response with { or [ and end with } or ]
        """

    // MARK: - Receipt Prompts

    private static let foodOnlyRule = """
        ONLY extract actual food/grocery items. IGNORE and DO NOT include:
        - Bags, shopping bags, carrier bags
        - Taxes, VAT, service charges
        - Discounts, coupons, promotions, savings
        - Deposits, bottle deposits, container fees
        - Subtotals, totals, change, payment info
        - Loyalty points, rewards, membership
        - Non-food items (cleaning supplies, toiletries, etc.)
        """

    private static let babyFoodFilter = """
        - Baby food, infant formula, baby cereal, baby snacks
        - Any items labeled for infants, babies, or toddlers
        """

    private static func buildFoodOnlyRule(filterBabyFood: Bool) -> String {
        filterBabyFood ? foodOnlyRule + "\n" + babyFoodFilter : foodOnlyRule
    }

    private static let receiptFieldRules = """
        - name: translate to English if needed
        - quantity_grams: ALWAYS provide weight in grams. Convert units (1kg=1000g, 500ml≈500g for liquids).
          If weight not shown, ESTIMATE based on typical package sizes:
          * Milk/juice carton: 1000g, small bottle: 500g
          * Bread loaf: 400-500g, baguette: 250g
          * Eggs (dozen): 600g, (6-pack): 300g
          * Cheese block: 200-400g, sliced: 150g
          * Meat/fish package: 300-500g
          * Canned goods: 400g, small can: 200g
          * Fresh produce: apple 180g, banana 120g, orange 200g
          * Yogurt: 125-150g per cup, large tub: 500g
          * Cereal box: 300-500g
          * Pasta/rice bag: 500g or 1000g
          * Snacks/chips: 150-200g
        - price: number without currency symbol
        """

    private static let receiptJSON = """
        {"store_name":"Store Name","receipt_date":"2025-01-25","items":[{"name":"Food name","quantity_grams":1000,"price":2.99,"category":"proteins","subcategory":"leanMeat"}]}
        """

    static func receiptImagePrompt(filterBabyFood: Bool) -> String {
        """
        Extract store name, date, and ONLY food items from this grocery receipt image.

        \(buildFoodOnlyRule(filterBabyFood: filterBabyFood))

        Required JSON structure:
        \(receiptJSON)

        Field rules:
        - store_name: string, or JSON null if not visible (not the string "null")
        - receipt_date: YYYY-MM-DD format string, or JSON null
        \(receiptFieldRules)
        - category: one of \(categoryList)
        - subcategory: from category's list, or null if unsure:
        \(categorySubcategoryMapping)
        \(strictOutputRules)
        """
    }

    static func receiptTextPrompt(_ text: String, filterBabyFood: Bool) -> String {
        """
        Extract store name, date, and ONLY food items from this receipt text.

        \(buildFoodOnlyRule(filterBabyFood: filterBabyFood))

        Receipt text:
        \(text)

        Required JSON structure:
        \(receiptJSON)

        Field rules:
        - store_name: string, or JSON null if not found (not the string "null")
        - receipt_date: YYYY-MM-DD format string, or JSON null
        \(receiptFieldRules)
        - category: one of \(categoryList)
        - subcategory: from category's list, or null if unsure:
        \(categorySubcategoryMapping)
        \(strictOutputRules)
        """
    }

    // MARK: - Nutrition Prompts

    private static let nutritionJSON = """
        {"food_name":"Product Name","calories":0,"protein":0,"carbohydrates":0,"fat":0,"saturatedFat":0,"omega3":0,"omega6":0,"sugar":0,"fiber":0,"sodium":0,"vitaminA":0,"vitaminC":0,"vitaminD":0,"calcium":0,"iron":0,"potassium":0}
        """

    private static let nutritionFieldRules = """
        - All values per 100g, ALL 16 fields REQUIRED (never null)
        - calories: kcal, protein/carbohydrates/fat/saturatedFat/omega3/omega6/sugar/fiber: grams
        - sodium/vitaminC/calcium/iron/potassium: mg, vitaminA/vitaminD: mcg
        - Use 0 if unknown, but provide best estimate when possible
        """

    static let nutritionLabelImagePrompt = """
        Extract the food/product name and nutrition values from this nutrition label image. Convert to per 100g.

        Required JSON structure:
        \(nutritionJSON)

        Field rules:
        - food_name: the product or food name visible on the label/packaging, or "Unknown Food" if not visible
        \(nutritionFieldRules)
        \(strictOutputRules)
        """

    static func nutritionLabelTextPrompt(_ text: String) -> String {
        """
        Extract the food/product name and nutrition values from this text. Convert to per 100g.

        Nutrition label text:
        \(text)

        Required JSON structure:
        \(nutritionJSON)

        Field rules:
        - food_name: the product or food name from the text, or "Unknown Food" if not found
        \(nutritionFieldRules)
        \(strictOutputRules)
        """
    }

    static func estimateNutritionPrompt(foodName: String, category: String) -> String {
        """
        Estimate typical nutrition values for: \(foodName) (category: \(category))

        Required JSON structure:
        \(nutritionJSON)

        Field rules:
        - food_name: "\(foodName)"
        \(nutritionFieldRules)
        \(strictOutputRules)
        """
    }

    /// Prompt for filling only empty nutrition fields while considering existing values
    static func fillEmptyNutritionPrompt(
        foodName: String,
        category: String,
        tags: [String],
        existingNutrition: [String: Double]
    ) -> String {
        let tagList = tags.isEmpty ? "none" : tags.joined(separator: ", ")
        let existingValues = existingNutrition
            .filter { $0.value > 0 }
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: ", ")

        let existingSection = existingValues.isEmpty ? "None provided yet." : existingValues

        return """
        Estimate missing nutrition values for this food item. ONLY provide values for fields that are empty/zero.

        Food information:
        - Name: \(foodName)
        - Category: \(category)
        - Tags: \(tagList)

        Existing nutrition values (per 100g) - DO NOT CHANGE THESE:
        \(existingSection)

        IMPORTANT RULES:
        1. Your estimates must be CONSISTENT with the existing values above
        2. If existing values suggest a certain food profile (e.g., high protein suggests meat/dairy), align your estimates accordingly
        3. Ensure macros (protein + carbs + fat) roughly add up to a sensible total with existing values
        4. If existing calories are provided, ensure your macro estimates would approximately match that calorie count
        5. Provide reasonable estimates for ALL fields in the JSON structure

        Required JSON structure:
        \(nutritionJSON)

        \(nutritionFieldRules)
        \(strictOutputRules)
        """
    }

    // MARK: - Category and Tags Suggestion Prompt

    static func suggestCategoryAndTagsPrompt(foodName: String, availableTags: [String]) -> String {
        let tagList = availableTags.isEmpty ? "(none available)" : availableTags.joined(separator: ", ")
        return """
        Suggest the best category, subcategory, and up to 3 most relevant tags for: "\(foodName)"

        Available categories and their subcategories (use rawValue format):
        \(categorySubcategoryMapping)

        Available tags: \(tagList)

        Required JSON structure:
        {"category":"proteins","subcategory":"leanMeat","tags":["tag1","tag2","tag3"]}

        Field rules:
        - category: one of \(categoryList) (required)
        - subcategory: one from the category's subcategories list, or null if none apply
        - tags: up to 3 most relevant tags from the available list, empty array if none fit
        \(strictOutputRules)
        """
    }

    // MARK: - Nutrition Target Suggestion Prompt

    static func suggestNutritionTargetsPrompt(members: [FamilyMember]) -> String {
        let membersJSON = members.compactMap { member -> String? in
            let dict: [String: Any] = [
                "name": member.name,
                "age": member.age,
                "weight": member.weight,
                "activityLevel": member.activityLevel.rawValue,
                "dietType": member.dietType.rawValue
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
                  let str = String(data: data, encoding: .utf8) else { return nil }
            return str
        }.joined(separator: ",")

        return """
        Calculate combined daily nutrition targets for this household based on family member profiles.

        Family members:
        [\(membersJSON)]

        Consider each member's:
        - Age and weight for base metabolic rate
        - Activity level for calorie multiplier
        - Diet type for macro ratio adjustments (e.g., keto = low carb/high fat, high protein = more protein)

        Sum all members' individual needs into household totals.

        Required JSON structure:
        {"calories":0,"protein":0,"carbohydrates":0,"fat":0,"saturatedFat":0,"omega3":0,"omega6":0,"sugar":0,"fiber":0,"sodium":0,"vitaminA":0,"vitaminC":0,"vitaminD":0,"calcium":0,"iron":0,"potassium":0,"explanation":"Brief explanation"}

        Field rules (ALL 17 fields REQUIRED, never null):
        - calories: total daily kcal for entire household
        - protein/carbohydrates/fat/saturatedFat: grams per day
        - omega3: grams (1.1-1.6g/adult), omega6: grams (11-17g/adult)
        - sugar/fiber: grams per day
        - sodium: mg (2300mg/adult limit)
        - vitaminA: mcg (700-900/adult), vitaminD: mcg (15-20/adult)
        - vitaminC: mg (75-90/adult), calcium: mg (1000-1200/adult)
        - iron: mg (8-18/adult), potassium: mg (2600-3400/adult)
        - explanation: 1-2 sentences explaining the key factors
        \(strictOutputRules)
        """
    }

    // MARK: - Food Matching Prompt

    static func matchFoodPrompt(itemName: String, existingFoods: [String]) -> String {
        let foodList = existingFoods.isEmpty ? "(none)" : existingFoods.joined(separator: ", ")
        return """
        Match "\(itemName)" to the most similar food from: \(foodList)

        Required JSON structure (when match found):
        {"foodName":"Exact Name From List","confidence":0.85,"isNewFood":false}

        Required JSON structure (when NO match found):
        {"foodName":null,"confidence":0,"isNewFood":true}

        Field rules:
        - foodName: EXACT name from the list above, or JSON null if no good match. NEVER use the string "null" - use actual JSON null
        - confidence: number from 0.0 to 1.0
        - isNewFood: true if confidence < 0.7 or no match, false otherwise
        \(strictOutputRules)
        """
    }
}

// MARK: - Shared JSON Parser

enum LLMJSONParser {
    static func parse<T: Decodable>(_ string: String, as type: T.Type) throws -> T {
        var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove markdown code blocks if present (fallback for non-compliant responses)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find JSON boundaries (handle any text before/after)
        if let jsonStart = cleaned.firstIndex(where: { $0 == "{" || $0 == "[" }),
           let jsonEnd = cleaned.lastIndex(where: { $0 == "}" || $0 == "]" }) {
            cleaned = String(cleaned[jsonStart...jsonEnd])
        }

        guard let data = cleaned.data(using: .utf8) else {
            throw LLMError.parseError("Invalid UTF-8 string")
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch let decodingError as DecodingError {
            let detail: String
            switch decodingError {
            case .keyNotFound(let key, _):
                detail = "Missing key: \(key.stringValue)"
            case .typeMismatch(let type, let context):
                detail = "Type mismatch for \(context.codingPath.map(\.stringValue).joined(separator: ".")): expected \(type)"
            case .valueNotFound(let type, let context):
                detail = "Null value for \(context.codingPath.map(\.stringValue).joined(separator: ".")): expected \(type)"
            case .dataCorrupted(let context):
                detail = "Corrupted data: \(context.debugDescription)"
            @unknown default:
                detail = decodingError.localizedDescription
            }
            throw LLMError.parseError(detail)
        } catch {
            throw LLMError.parseError(error.localizedDescription)
        }
    }
}
