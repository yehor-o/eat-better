import Foundation

public struct ShoppingItem: Hashable, Sendable {
    public var ingredient: Ingredient
    public var gramsNeeded: Double
    public var packs: Int
    public var costUAH: Double
}

public struct ShoppingList: Hashable, Sendable {
    public var items: [ShoppingItem]
    public var totalUAH: Double { items.reduce(0) { $0 + $1.costUAH } }
}

/// A recipe cooked a given number of times in a plan (e.g. one batch of 3 servings = 1 batch).
public struct PlannedBatch: Hashable, Sendable {
    public var recipe: Recipe
    /// Multiplier applied to the recipe's amounts (1 = recipe as written).
    public var scale: Double

    public init(recipe: Recipe, scale: Double = 1) {
        self.recipe = recipe
        self.scale = scale
    }
}

public enum ShoppingPlanner {
    /// Builds one shopping list for a plan. Ingredients ticked as available are skipped
    /// entirely (the fridge is tracked as have / don't have, not by quantity).
    public static func list(
        for plan: [PlannedBatch],
        catalog: Catalog,
        available: Set<String>,
        prices: [String: Double] = [:]
    ) -> ShoppingList {
        var grams: [String: Double] = [:]
        for batch in plan {
            for item in batch.recipe.ingredients where !item.optional && !available.contains(item.ingredientID) {
                grams[item.ingredientID, default: 0] += item.grams * batch.scale
            }
        }
        let items = grams.compactMap { id, needed -> ShoppingItem? in
            guard let ingredient = catalog.ingredient(id) else { return nil }
            let packs = max(1, Int((needed / ingredient.packGrams).rounded(.up)))
            let price = prices[id] ?? ingredient.packPriceUAH
            return ShoppingItem(ingredient: ingredient, gramsNeeded: needed, packs: packs, costUAH: Double(packs) * price)
        }
        .sorted { ($0.ingredient.category.rawValue, $0.ingredient.id) < ($1.ingredient.category.rawValue, $1.ingredient.id) }
        return ShoppingList(items: items)
    }
}
