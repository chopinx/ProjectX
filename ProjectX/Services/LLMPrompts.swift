import Foundation

/// Shared prompts for LLM services
/// All prompts enforce strict JSON-only output for reliable parsing
enum LLMPrompts {

    // MARK: - Strict Output Instructions (appended to all prompts)

    private static let strictOutputRules = """

        CRITICAL OUTPUT REQUIREMENTS:
        - Output ONLY the JSON object/array, nothing else
        - Do NOT wrap in markdown code blocks (no ```)
        - Do NOT include any text before or after the JSON
        - Do NOT include comments or explanations
        - Do NOT say "Here is" or any introduction
        - Ensure valid JSON syntax (proper quotes, commas, brackets)
        - Use null for missing values, not "null" string
        - Use numbers without quotes for numeric fields
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

    static let receiptImagePrompt = """
        Extract store name and ONLY food items from this grocery receipt image.

        \(foodOnlyRule)

        Required JSON structure:
        {"store_name":"Store Name","items":[{"name":"Food name in English","quantity_grams":1000,"price":2.99,"category":"produce"}]}

        Field rules:
        - store_name: string or null if not visible
        - name: translate to English if needed
        - quantity_grams: convert all units to grams (1kg=1000, 500ml=500, estimate pieces)
        - price: number without currency symbol
        - category: one of produce/dairy/meat/seafood/bakery/beverages/snacks/frozen/pantry/other
        \(strictOutputRules)
        """

    static func receiptTextPrompt(_ text: String) -> String {
        """
        Extract store name and ONLY food items from this receipt text.

        \(foodOnlyRule)

        Receipt text:
        \(text)

        Required JSON structure:
        {"store_name":"Store Name","items":[{"name":"Food name in English","quantity_grams":1000,"price":2.99,"category":"produce"}]}

        Field rules:
        - store_name: string or null if not found
        - name: translate to English if needed
        - quantity_grams: convert all units to grams (1kg=1000, 500ml=500, estimate pieces)
        - price: number without currency symbol
        - category: one of produce/dairy/meat/seafood/bakery/beverages/snacks/frozen/pantry/other
        \(strictOutputRules)
        """
    }

    // MARK: - Nutrition Label Prompts

    static let nutritionLabelImagePrompt = """
        Extract nutrition values from this nutrition label image. Convert to per 100g.

        Required JSON structure:
        {"calories":0,"protein":0,"carbohydrates":0,"fat":0,"saturatedFat":0,"sugar":0,"fiber":0,"sodium":0}

        Field rules:
        - All macros in grams per 100g
        - calories: kcal per 100g
        - sodium: mg per 100g
        - Use 0 for missing values, estimate if possible
        \(strictOutputRules)
        """

    static func nutritionLabelTextPrompt(_ text: String) -> String {
        """
        Extract nutrition values from this text. Convert to per 100g.

        Nutrition label text:
        \(text)

        Required JSON structure:
        {"calories":0,"protein":0,"carbohydrates":0,"fat":0,"saturatedFat":0,"sugar":0,"fiber":0,"sodium":0}

        Field rules:
        - All macros in grams per 100g
        - calories: kcal per 100g
        - sodium: mg per 100g
        - Use 0 for missing values
        \(strictOutputRules)
        """
    }

    // MARK: - Nutrition Estimation Prompt

    static func estimateNutritionPrompt(foodName: String, category: String) -> String {
        """
        Estimate nutrition values for: \(foodName) (category: \(category))

        Required JSON structure:
        {"calories":0,"protein":0,"carbohydrates":0,"fat":0,"saturatedFat":0,"sugar":0,"fiber":0,"sodium":0}

        Field rules:
        - All values per 100g based on typical values for this food
        - calories: kcal
        - protein/carbohydrates/fat/saturatedFat/sugar/fiber: grams
        - sodium: mg
        \(strictOutputRules)
        """
    }

    // MARK: - Food Matching Prompt

    static func matchFoodPrompt(itemName: String, existingFoods: [String]) -> String {
        let foodList = existingFoods.isEmpty ? "(none)" : existingFoods.joined(separator: ", ")
        return """
        Match "\(itemName)" to the most similar food from: \(foodList)

        Required JSON structure:
        {"foodName":"matched name or null","confidence":0.85,"isNewFood":false}

        Field rules:
        - foodName: exact name from list, or null if no good match
        - confidence: 0.0 to 1.0
        - isNewFood: true if confidence < 0.7 or no match, false otherwise
        - If list is empty, return {"foodName":null,"confidence":0,"isNewFood":true}
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
