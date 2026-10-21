import EatBetterCore
import SwiftData
import SwiftUI

/// Have / don't have checklist. Only the user changes it; cooking never removes anything.
struct FridgeView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query private var pantry: [PantryItem]

    var body: some View {
        NavigationStack {
            List {
                if let catalog = store.catalog {
                    let have = Set(pantry.map(\.ingredientID))
                    ForEach(IngredientCategory.allCases, id: \.self) { category in
                        let items = catalog.ingredients.values
                            .filter { $0.category == category }
                            .sorted { $0.name.current < $1.name.current }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { ingredient in
                                    Toggle(ingredient.name.current, isOn: Binding(
                                        get: { have.contains(ingredient.id) },
                                        set: { setHave($0, ingredientID: ingredient.id) }
                                    ))
                                }
                            } header: {
                                Text(category.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fridge")
        }
    }

    private func setHave(_ on: Bool, ingredientID: String) {
        let existing = pantry.filter { $0.ingredientID == ingredientID }
        if on {
            if existing.isEmpty { context.insert(PantryItem(ingredientID: ingredientID)) }
        } else {
            existing.forEach { context.delete($0) }
        }
    }
}
