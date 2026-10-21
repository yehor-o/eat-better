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
