import Foundation
import Testing
@testable import EatBetterCore

private func bundledCatalog() throws -> Catalog {
    try Catalog(ingredients: Catalog.bundledIngredients(), recipes: Catalog.demoRecipes())
}

@Suite struct CatalogTests {
    @Test func bundledDataLoadsAndIsConsistent() throws {
        let catalog = try bundledCatalog()
        #expect(catalog.ingredients.count >= 10)
        #expect(catalog.recipes.count >= 5)
        #expect(Set(catalog.recipes.map(\.id)).count == catalog.recipes.count)
        for recipe in catalog.recipes {
            #expect(!recipe.steps.isEmpty)
            #expect(recipe.servings >= 1)
        }
    }

    @Test func unknownIngredientIsRejected() throws {
        let recipe = Recipe(
            id: "r", name: .init(en: "R", uk: "R"), mealTypes: [.lunch], servings: 1, totalMinutes: 5,
            ingredients: [RecipeIngredient(ingredientID: "nope", grams: 10)], steps: []
        )
        #expect(throws: CatalogError.unknownIngredient(recipeID: "r", ingredientID: "nope")) {
            try Catalog(ingredients: [], recipes: [recipe])
        }
    }
}

@Suite struct DailyTargetsTests {
    // Example profile used in docs: 70 kg, 180 cm, 25 y, male, moderate activity, gaining.
    let profile = BodyProfile(weightKg: 70, heightCm: 180, ageYears: 25, sex: .male, activity: .moderate, goal: .gain)

    @Test func bmrMatchesMifflinStJeor() {
        #expect(DailyTargets.bmr(for: profile) == 1705)
    }

    @Test func targetsForGain() {
        let t = DailyTargets.targets(for: profile)
        #expect(abs(t.kcal - 3042.75) < 0.01)
        #expect(t.protein == 126)
        #expect(t.fat == 70)
        #expect(abs(t.carbs - (3042.75 - 126 * 4 - 70 * 9) / 4) < 0.01)
    }

    @Test func maintainHasNoSurplus() {
        var p = profile
        p.goal = .maintain
        #expect(abs(DailyTargets.targets(for: p).kcal - 1705 * 1.55) < 0.01)
    }
}

@Suite struct RecipeMathTests {
    @Test func perServingNutritionSumsIngredients() throws {
        let catalog = try bundledCatalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "demo_cottage_banana" })
        let n = catalog.nutritionPerServing(of: recipe)
        // 200 g cottage cheese + 120 g banana
        #expect(abs(n.kcal - (121 * 2 + 89 * 1.2)) < 0.001)
        #expect(abs(n.protein - (17 * 2 + 1.1 * 1.2)) < 0.001)
    }

    @Test func servingsDivideTotal() throws {
        let catalog = try bundledCatalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "demo_chicken_buckwheat" })
        let total = catalog.totalNutrition(of: recipe)
        let one = catalog.nutritionPerServing(of: recipe)
        #expect(abs(one.kcal * 3 - total.kcal) < 0.001)
    }

    @Test func scalingMultipliesAmountsAndServings() throws {
        let catalog = try bundledCatalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "demo_pasta_tuna" })
        let tripled = recipe.scaled(by: 3)
        #expect(tripled.servings == 6)
        #expect(tripled.ingredients.first?.grams == 600)
        #expect(abs(catalog.totalNutrition(of: tripled).kcal - catalog.totalNutrition(of: recipe).kcal * 3) < 0.001)
    }

    @Test func householdAmountUsesUnits() throws {
        let catalog = try bundledCatalog()
        let eggs = try #require(catalog.householdAmount(ingredientID: "egg", grams: 150))
        #expect(eggs.count == 3)
        let oil = try #require(catalog.householdAmount(ingredientID: "sunflower_oil", grams: 26))
        #expect(oil.unit.name.en == "tbsp")
        #expect(oil.count == 2)
        #expect(catalog.householdAmount(ingredientID: "chicken_breast", grams: 600) == nil)
    }
}

@Suite struct PantryMatcherTests {
    @Test func allRequiredIngredientsMeansCanCook() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: ["cottage_cheese", "banana"])
        #expect(result.canCookNow.map(\.recipe.id).contains("demo_cottage_banana"))
    }

    @Test func optionalIngredientsDoNotBlock() throws {
        let catalog = try bundledCatalog()
        // Oatmeal needs oats, milk, banana; salt is optional.
        let result = PantryMatcher.match(catalog: catalog, available: ["oats", "milk", "banana"])
        #expect(result.canCookNow.map(\.recipe.id).contains("demo_oatmeal_banana"))
    }

    @Test func oneMissingIngredientIsReportedWithPrice() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: ["cottage_cheese"], prices: ["banana": 80])
        let match = try #require(result.almost.first { $0.recipe.id == "demo_cottage_banana" })
        #expect(match.missing.map(\.id) == ["banana"])
        #expect(match.missingCostUAH == 80)
    }

    @Test func tooManyMissingIsExcluded() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: [])
        #expect(!result.almost.contains { $0.recipe.id == "demo_chicken_buckwheat" })
        #expect(result.canCookNow.isEmpty)
    }

    @Test func almostIsSortedByMissingCount() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: ["banana", "milk"])
        let counts = result.almost.map(\.missing.count)
        #expect(counts == counts.sorted())
    }
}

@Suite struct ShoppingPlannerTests {
    @Test func aggregatesAcrossRecipesAndSkipsAvailable() throws {
        let catalog = try bundledCatalog()
        let chicken = try #require(catalog.recipes.first { $0.id == "demo_chicken_buckwheat" })
        let rice = try #require(catalog.recipes.first { $0.id == "demo_rice_chicken_veg" })
        let list = ShoppingPlanner.list(
            for: [PlannedBatch(recipe: chicken), PlannedBatch(recipe: rice)],
            catalog: catalog,
            available: ["sunflower_oil"]
        )
        let ids = list.items.map(\.ingredient.id)
        #expect(!ids.contains("sunflower_oil"))
        #expect(!ids.contains("salt")) // optional
        let chickenItem = try #require(list.items.first { $0.ingredient.id == "chicken_breast" })
        #expect(chickenItem.gramsNeeded == 1050)
        #expect(chickenItem.packs == 2)
        #expect(chickenItem.costUAH == 500)
        #expect(list.totalUAH == list.items.reduce(0) { $0 + $1.costUAH })
    }

    @Test func scaleMultipliesNeededGrams() throws {
        let catalog = try bundledCatalog()
        let pasta = try #require(catalog.recipes.first { $0.id == "demo_pasta_tuna" })
        let list = ShoppingPlanner.list(for: [PlannedBatch(recipe: pasta, scale: 3)], catalog: catalog, available: [])
        let item = try #require(list.items.first { $0.ingredient.id == "pasta" })
        #expect(item.gramsNeeded == 600)
        #expect(item.packs == 2)
    }
}
