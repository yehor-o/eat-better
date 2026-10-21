import Foundation

/// Text stored in both supported UI languages.
public struct LocalizedText: Codable, Hashable, Sendable {
    public var en: String
    public var uk: String

    public init(en: String, uk: String) {
        self.en = en
        self.uk = uk
    }

    /// Picks the Ukrainian text when the language code starts with "uk", English otherwise.
    public func resolved(languageCode: String?) -> String {
        languageCode?.hasPrefix("uk") == true ? uk : en
    }
}

/// Calories and macronutrients. Used both "per 100 g" and as absolute totals.
public struct Nutrition: Codable, Hashable, Sendable {
    public var kcal: Double
    public var protein: Double
    public var fat: Double
    public var carbs: Double

    public init(kcal: Double, protein: Double, fat: Double, carbs: Double) {
        self.kcal = kcal
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
    }

    public static let zero = Nutrition(kcal: 0, protein: 0, fat: 0, carbs: 0)

    public static func + (lhs: Nutrition, rhs: Nutrition) -> Nutrition {
        Nutrition(
            kcal: lhs.kcal + rhs.kcal,
            protein: lhs.protein + rhs.protein,
            fat: lhs.fat + rhs.fat,
            carbs: lhs.carbs + rhs.carbs
        )
    }

    public static func * (lhs: Nutrition, factor: Double) -> Nutrition {
        Nutrition(
            kcal: lhs.kcal * factor,
            protein: lhs.protein * factor,
            fat: lhs.fat * factor,
            carbs: lhs.carbs * factor
        )
    }
}

/// A household measure for an ingredient, e.g. "1 egg = 50 g" or "1 tbsp oil = 13 g".
public struct HouseholdUnit: Codable, Hashable, Sendable {
    public var name: LocalizedText
    public var grams: Double

    public init(name: LocalizedText, grams: Double) {
        self.name = name
        self.grams = grams
    }
}

public enum IngredientCategory: String, Codable, CaseIterable, Sendable {
    case meatFish, dairyEggs, grains, vegetables, fruits, bakery, oilsSpices, canned, other
}

/// A generic ingredient from the shared catalog (no personal data).
public struct Ingredient: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: LocalizedText
    public var category: IngredientCategory
    /// Nutrition per 100 g of the ingredient as it is weighed in recipes.
    public var per100g: Nutrition
    /// Size of the typical pack in a store, in grams.
    public var packGrams: Double
    /// Approximate price of one pack, UAH (Ukrainian supermarkets). Overridable on device.
    public var packPriceUAH: Double
    /// Household measures to show next to grams.
    public var units: [HouseholdUnit]

    public init(
        id: String,
        name: LocalizedText,
        category: IngredientCategory,
        per100g: Nutrition,
        packGrams: Double,
        packPriceUAH: Double,
        units: [HouseholdUnit] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.per100g = per100g
        self.packGrams = packGrams
        self.packPriceUAH = packPriceUAH
        self.units = units
    }
}

public enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast, lunch, dinner, snack
}

public struct RecipeIngredient: Codable, Hashable, Sendable {
    public var ingredientID: String
    /// Amount for the whole recipe (all servings), in grams.
    public var grams: Double
    /// Optional ingredients (e.g. spices "to taste") never block cooking.
    public var optional: Bool

    public init(ingredientID: String, grams: Double, optional: Bool = false) {
        self.ingredientID = ingredientID
        self.grams = grams
        self.optional = optional
    }

    enum CodingKeys: String, CodingKey { case ingredientID = "ingredient", grams, optional }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ingredientID = try c.decode(String.self, forKey: .ingredientID)
        grams = try c.decode(Double.self, forKey: .grams)
        optional = try c.decodeIfPresent(Bool.self, forKey: .optional) ?? false
    }
}

public struct RecipeStep: Codable, Hashable, Sendable {
    public var text: LocalizedText
    /// When set, cooking mode offers a timer for this step.
    public var timerMinutes: Int?

    public init(text: LocalizedText, timerMinutes: Int? = nil) {
        self.text = text
        self.timerMinutes = timerMinutes
    }
}

public struct Recipe: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: LocalizedText
    public var mealTypes: [MealType]
    public var servings: Int
    public var totalMinutes: Int
    /// Days a cooked portion keeps in the fridge. `nil` means the app default.
    public var storageDays: Int?
    public var ingredients: [RecipeIngredient]
    public var steps: [RecipeStep]

    public init(
        id: String,
        name: LocalizedText,
        mealTypes: [MealType],
        servings: Int,
        totalMinutes: Int,
        storageDays: Int? = nil,
        ingredients: [RecipeIngredient],
        steps: [RecipeStep]
    ) {
        self.id = id
        self.name = name
        self.mealTypes = mealTypes
        self.servings = servings
        self.totalMinutes = totalMinutes
        self.storageDays = storageDays
        self.ingredients = ingredients
        self.steps = steps
    }
}
