import EatBetterCore
import SwiftData
import SwiftUI

struct RecipesView: View {
    @Environment(CatalogStore.self) private var store
    @Query private var pantry: [PantryItem]
    @Query private var priceOverrides: [PriceOverride]

    var body: some View {
        NavigationStack {
            Group {
                if let catalog = store.catalog {
                    list(catalog: catalog)
                } else {
                    ContentUnavailableView(
                        "Could not load recipes",
                        systemImage: "exclamationmark.triangle",
                        description: Text(verbatim: store.loadError ?? "")
                    )
                }
            }
            .navigationTitle("Recipes")
        }
    }

    private func list(catalog: Catalog) -> some View {
        let prices = Dictionary(priceOverrides.map { ($0.ingredientID, $0.packPriceUAH) }, uniquingKeysWith: { a, _ in a })
        let matches = PantryMatcher.match(catalog: catalog, available: Set(pantry.map(\.ingredientID)), prices: prices)
        return List {
            Section("Can cook now") {
                if matches.canCookNow.isEmpty {
                    Text("Tick what you have in the Fridge tab.").foregroundStyle(.secondary)
                }
                ForEach(matches.canCookNow, id: \.recipe.id) { match in
                    NavigationLink(value: match.recipe.id) { RecipeRow(recipe: match.recipe, catalog: catalog) }
                }
            }
            if !matches.almost.isEmpty {
                Section("Missing 1–2 ingredients") {
                    ForEach(matches.almost, id: \.recipe.id) { match in
                        NavigationLink(value: match.recipe.id) {
                            VStack(alignment: .leading, spacing: 4) {
                                RecipeRow(recipe: match.recipe, catalog: catalog)
                                Text("Buy: \(match.missing.map(\.name.current).joined(separator: ", ")) · ~\(Int(match.missingCostUAH.rounded())) ₴")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            Section("All recipes") {
                ForEach(catalog.recipes) { recipe in
                    NavigationLink(value: recipe.id) { RecipeRow(recipe: recipe, catalog: catalog) }
                }
            }
        }
        .navigationDestination(for: String.self) { id in
            if let recipe = catalog.recipes.first(where: { $0.id == id }) {
                RecipeDetailView(recipe: recipe, catalog: catalog)
            }
        }
    }
}

struct RecipeRow: View {
    let recipe: Recipe
    let catalog: Catalog

    var body: some View {
        let n = catalog.nutritionPerServing(of: recipe)
        VStack(alignment: .leading, spacing: 2) {
            Text(recipe.name.current)
            Text("\(Int(n.kcal.rounded())) kcal · \(Int(n.protein.rounded())) g protein · \(recipe.totalMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
