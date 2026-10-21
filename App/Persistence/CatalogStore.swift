import EatBetterCore
import Foundation
import Observation

/// Loads the shared ingredient catalog and the recipes.
/// Private data (Private/*.json, never committed) is copied into the app bundle at build time
/// by scripts/copy-private-data.sh; without it the demo recipes are used.
@MainActor
@Observable
final class CatalogStore {
    private(set) var catalog: Catalog?
    /// Typical dishes for logging food cooked elsewhere (D-016), plus private ones if bundled.
    private(set) var dishes: [Food] = []
    private(set) var isUsingDemoRecipes = true
    /// Ingredients whose pack and price come from the private price file (T-007).
    private(set) var privatePriceCount = 0
    private(set) var loadError: String?

    init() {
        load()
    }

    func load() {
        do {
            var ingredients = try Catalog.bundledIngredients()
            if let extra = Bundle.main.url(forResource: "private-ingredients", withExtension: "json") {
                ingredients += try JSONDecoder().decode([Ingredient].self, from: Data(contentsOf: extra))
            }
            let recipes: [Recipe]
            if let url = Bundle.main.url(forResource: "private-recipes", withExtension: "json") {
                recipes = try Catalog.decodeRecipes(from: Data(contentsOf: url))
                isUsingDemoRecipes = false
            } else {
                recipes = try Catalog.demoRecipes()
                isUsingDemoRecipes = true
            }
            var loaded = try Catalog(ingredients: ingredients, recipes: recipes)
            if let url = Bundle.main.url(forResource: "private-prices", withExtension: "json") {
                let packs = try JSONDecoder().decode([PackPrice].self, from: Data(contentsOf: url))
                loaded = loaded.applying(packs)
                privatePriceCount = packs.count
            }
            catalog = loaded
            dishes = try Catalog.bundledDishes()
            if let extra = Bundle.main.url(forResource: "private-dishes", withExtension: "json") {
                dishes += try JSONDecoder().decode([Food].self, from: Data(contentsOf: extra))
            }
            loadError = nil
        } catch {
            privatePriceCount = 0
            catalog = nil
            loadError = String(describing: error)
        }
    }

    /// The catalog with the owner's own prices and packs from this device on top.
    func catalog(with overrides: [PriceOverride]) -> Catalog? {
        catalog?.applying(overrides.map(\.packPrice))
    }
}
