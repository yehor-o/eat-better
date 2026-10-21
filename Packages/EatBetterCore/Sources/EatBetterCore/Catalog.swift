import Foundation

public enum CatalogError: Error, Equatable {
    case missingResource(String)
    case unknownIngredient(recipeID: String, ingredientID: String)
}

/// Ingredients plus recipes, validated so every recipe only references known ingredients.
public struct Catalog: Sendable {
    public let ingredients: [String: Ingredient]
    public let recipes: [Recipe]

    public init(ingredients: [Ingredient], recipes: [Recipe]) throws {
        var byID: [String: Ingredient] = [:]
        for ingredient in ingredients { byID[ingredient.id] = ingredient }
        for recipe in recipes {
            for item in recipe.ingredients where byID[item.ingredientID] == nil {
                throw CatalogError.unknownIngredient(recipeID: recipe.id, ingredientID: item.ingredientID)
            }
        }
        self.ingredients = byID
        self.recipes = recipes
    }

    /// Already checked: same recipes, ingredients changed only in price or pack.
    init(validated ingredients: [String: Ingredient], recipes: [Recipe]) {
        self.ingredients = ingredients
        self.recipes = recipes
    }

    public func ingredient(_ id: String) -> Ingredient? { ingredients[id] }

    /// Shared ingredient catalog bundled with the package.
    public static func bundledIngredients() throws -> [Ingredient] {
        try decodeResource("ingredients", as: [Ingredient].self)
    }

    /// Demo recipes bundled with the package; used when no private recipe file is present.
    public static func demoRecipes() throws -> [Recipe] {
        try decodeResource("demo-recipes", as: [Recipe].self)
    }

    public static func decodeRecipes(from data: Data) throws -> [Recipe] {
        try JSONDecoder().decode([Recipe].self, from: data)
    }

    private static func decodeResource<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw CatalogError.missingResource(name)
        }
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}

/// A store pack and its price for one ingredient: from the private price file (T-007) or the
/// owner's own entry on the device (T-011).
public struct PackPrice: Codable, Hashable, Sendable {
    public var ingredientID: String
    /// 0 keeps the catalog pack size.
    public var packGrams: Double
    public var packPriceUAH: Double

    public init(ingredientID: String, packGrams: Double = 0, packPriceUAH: Double) {
        self.ingredientID = ingredientID
        self.packGrams = packGrams
        self.packPriceUAH = packPriceUAH
    }

    enum CodingKeys: String, CodingKey { case ingredientID = "ingredient", packGrams, packPriceUAH }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ingredientID = try c.decode(String.self, forKey: .ingredientID)
        packGrams = try c.decodeIfPresent(Double.self, forKey: .packGrams) ?? 0
        packPriceUAH = try c.decode(Double.self, forKey: .packPriceUAH)
    }
}

public extension Catalog {
    /// The same catalog with these packs and prices in place of the catalog ones. Unknown
    /// ingredients and non-positive prices are ignored.
    func applying(_ packs: [PackPrice]) -> Catalog {
        var byID = ingredients
        for pack in packs where pack.packPriceUAH > 0 {
            guard var ingredient = byID[pack.ingredientID] else { continue }
            ingredient.packPriceUAH = pack.packPriceUAH
            if pack.packGrams > 0 { ingredient.packGrams = pack.packGrams }
            byID[pack.ingredientID] = ingredient
        }
        return Catalog(validated: byID, recipes: recipes)
    }
}
