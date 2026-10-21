import EatBetterCore
import Foundation
import SwiftData

extension ModelContext {
    /// Writes right away instead of waiting for autosave, so killing the app right after an
    /// important action loses nothing.
    func saveNow() {
        try? save()
    }

    /// A recipe was cooked: every serving becomes a ready portion (spec #9). The fridge ticks
    /// stay as they are (D-006).
    @MainActor
    func addCookedPortions(of recipe: Recipe, catalog: Catalog, defaultStorageDays: Int) {
        let days = recipe.storageDays ?? defaultStorageDays
        let expires = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
        let perServing = catalog.nutritionPerServing(of: recipe)
        for _ in 0..<max(recipe.servings, 1) {
            insert(ReadyPortion(title: recipe.name.current, recipeID: recipe.id, nutrition: perServing, expiresAt: expires))
        }
        saveNow()
    }
}
