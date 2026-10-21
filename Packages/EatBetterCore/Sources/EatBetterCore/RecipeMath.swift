import Foundation

public extension Catalog {
    /// Nutrition of the whole recipe (all servings).
    func totalNutrition(of recipe: Recipe) -> Nutrition {
        recipe.ingredients.reduce(.zero) { sum, item in
            guard let ingredient = ingredient(item.ingredientID) else { return sum }
            return sum + ingredient.per100g * (item.grams / 100)
        }
    }

    /// Nutrition of one serving.
    func nutritionPerServing(of recipe: Recipe) -> Nutrition {
        totalNutrition(of: recipe) * (1 / Double(max(recipe.servings, 1)))
    }

    /// Picks the household unit that expresses `grams` most naturally, e.g. "3 × egg".
    /// Returns nil when the ingredient has no units.
    func householdAmount(ingredientID: String, grams: Double) -> (unit: HouseholdUnit, count: Double)? {
        guard let units = ingredient(ingredientID)?.units, !units.isEmpty else { return nil }
        // Prefer the largest unit that still gives a count of at least 1, rounded to halves.
        let candidates = units.sorted { $0.grams > $1.grams }
        let unit = candidates.first { grams / $0.grams >= 1 } ?? candidates.last!
        let count = (grams / unit.grams * 2).rounded() / 2
        return (unit, max(count, 0.5))
    }
}

public extension Recipe {
    /// Returns a copy with every ingredient amount and the serving count scaled.
    func scaled(by factor: Double) -> Recipe {
        var copy = self
        copy.servings = max(1, Int((Double(servings) * factor).rounded()))
        copy.ingredients = ingredients.map {
            RecipeIngredient(ingredientID: $0.ingredientID, grams: $0.grams * factor, optional: $0.optional)
        }
        return copy
    }
}
