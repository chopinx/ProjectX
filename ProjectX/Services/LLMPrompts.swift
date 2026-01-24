import Foundation

/// Shared prompts for LLM services
enum LLMPrompts {
    static let receiptImagePrompt = """
        Analyze this grocery receipt image and extract all food items.
        Translate any non-English text to English.

        Return a JSON array with this exact structure:
        [
          {
            "name": "English food name",
            "quantity_grams": 1000,
            "price": 2.99,
            "category": "produce/dairy/meat/seafood/bakery/beverages/snacks/frozen/pantry/other"
          }
        ]

        Rules:
        - Translate German/other languages to English
        - Convert ALL quantities to grams:
          - "1 kg" → 1000
          - "500 ml" → 500 (treat 1ml ≈ 1g)
          - "2 pcs" → estimate weight (e.g., "2 apples" → 360)
          - "1.5 L" → 1500
        - Price should be a number without currency symbol
        - Only return the JSON array, no other text
        """

    static func receiptTextPrompt(_ text: String) -> String {
        """
        Parse this grocery receipt text and extract all food items.
        Translate any non-English text to English.

        Receipt text:
        \(text)

        Return a JSON array with this exact structure:
        [
          {
            "name": "English food name",
            "quantity_grams": 1000,
            "price": 2.99,
            "category": "produce/dairy/meat/seafood/bakery/beverages/snacks/frozen/pantry/other"
          }
        ]

        Rules:
        - Translate German/other languages to English
        - Convert ALL quantities to grams:
          - "1 kg" → 1000
          - "500 ml" → 500 (treat 1ml ≈ 1g)
          - "2 pcs" → estimate weight (e.g., "2 apples" → 360)
          - "1.5 L" → 1500
        - If quantity is not specified, estimate a reasonable default
        - Price should be a number without currency symbol
        - Only return the JSON array, no other text
        """
    }

    static let nutritionLabelImagePrompt = """
        Extract nutrition information from this nutrition label image.
        Convert all values to per 100g.

        Return JSON with this exact structure:
        {
          "calories": 0,
          "protein": 0,
          "carbohydrates": 0,
          "fat": 0,
          "saturatedFat": 0,
          "sugar": 0,
          "fiber": 0,
          "sodium": 0
        }

        Rules:
        - All values per 100g
        - Calories in kcal
        - Protein, carbs, fat, saturatedFat, sugar, fiber in grams
        - Sodium in mg
        - If a value is not shown, estimate based on food type or use 0
        - Only return the JSON object, no other text
        """

    static func nutritionLabelTextPrompt(_ text: String) -> String {
        """
        Parse this nutrition label text and extract nutrition values.
        Convert all values to per 100g.

        Nutrition label text:
        \(text)

        Return JSON with this exact structure:
        {
          "calories": 0,
          "protein": 0,
          "carbohydrates": 0,
          "fat": 0,
          "saturatedFat": 0,
          "sugar": 0,
          "fiber": 0,
          "sodium": 0
        }

        Rules:
        - All values per 100g
        - Calories in kcal
        - Protein, carbs, fat, saturatedFat, sugar, fiber in grams
        - Sodium in mg
        - If a value is not shown, use 0
        - Only return the JSON object, no other text
        """
    }

    static func estimateNutritionPrompt(foodName: String, category: String) -> String {
        """
        Estimate typical nutrition values for: \(foodName) (category: \(category))

        Return JSON with this exact structure:
        {
          "calories": 0,
          "protein": 0,
          "carbohydrates": 0,
          "fat": 0,
          "saturatedFat": 0,
          "sugar": 0,
          "fiber": 0,
          "sodium": 0
        }

        Rules:
        - All values per 100g
        - Use typical/average values for this food
        - Calories in kcal
        - Protein, carbs, fat, saturatedFat, sugar, fiber in grams
        - Sodium in mg
        - Only return the JSON object, no other text
        """
    }

    static func matchFoodPrompt(itemName: String, existingFoods: [String]) -> String {
        let foodList = existingFoods.joined(separator: "\n")
        return """
        Match this receipt item to the most similar food in the list.

        Receipt item: "\(itemName)"

        Existing foods:
        \(foodList.isEmpty ? "(empty list)" : foodList)

        Return JSON with this exact structure:
        {
          "foodName": "matched food name or null if no match",
          "confidence": 0.0 to 1.0,
          "isNewFood": true/false
        }

        Rules:
        - If confidence < 0.7, set isNewFood to true
        - If list is empty, set isNewFood to true
        - foodName should be null if isNewFood is true
        - Only return the JSON object, no other text
        """
    }
}

// MARK: - Shared JSON Parser

enum LLMJSONParser {
    static func parse<T: Decodable>(_ string: String, as type: T.Type) throws -> T {
        var cleaned = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw LLMError.parseError("Invalid UTF-8 string")
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw LLMError.parseError(error.localizedDescription)
        }
    }
}
