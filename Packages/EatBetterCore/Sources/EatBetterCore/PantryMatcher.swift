import Foundation

/// How well a recipe fits what is currently marked as "have" in the fridge.
public struct RecipeMatch: Hashable, Sendable {
    public var recipe: Recipe
    /// Required ingredients that are not marked as available.
    public var missing: [Ingredient]
    /// Cost of buying one pack of every missing ingredient, UAH.
    public var missingCostUAH: Double

    public var canCookNow: Bool { missing.isEmpty }
}

public struct PantryMatches: Sendable {
    public var canCookNow: [RecipeMatch]
    /// Recipes missing 1...`maxMissing` ingredients, fewest missing first, then cheapest.
    public var almost: [RecipeMatch]
}

public enum PantryMatcher {
    /// - Parameters:
    ///   - available: ids of ingredients ticked as "have". The fridge is never modified here.
    ///   - prices: per-device pack price overrides by ingredient id.
    public static func match(
        catalog: Catalog,
        available: Set<String>,
        prices: [String: Double] = [:],
        maxMissing: Int = 2
    ) -> PantryMatches {
        var ready: [RecipeMatch] = []
        var almost: [RecipeMatch] = []
        for recipe in catalog.recipes {
            let missingIDs = Set(recipe.ingredients.filter { !$0.optional && !available.contains($0.ingredientID) }
                .map(\.ingredientID))
            let missing = missingIDs.compactMap { catalog.ingredient($0) }.sorted { $0.id < $1.id }
            let cost = missing.reduce(0) { $0 + (prices[$1.id] ?? $1.packPriceUAH) }
            let match = RecipeMatch(recipe: recipe, missing: missing, missingCostUAH: cost)
            if missing.isEmpty {
                ready.append(match)
            } else if missing.count <= maxMissing {
                almost.append(match)
            }
        }
        almost.sort {
            ($0.missing.count, $0.missingCostUAH, $0.recipe.id) < ($1.missing.count, $1.missingCostUAH, $1.recipe.id)
        }
        ready.sort { $0.recipe.id < $1.recipe.id }
        return PantryMatches(canCookNow: ready, almost: almost)
    }
}
