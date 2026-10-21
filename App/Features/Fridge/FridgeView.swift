import EatBetterCore
import SwiftData
import SwiftUI

/// Have / don't have checklist. Only the user changes it; cooking never removes anything.
struct FridgeView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query private var pantry: [PantryItem]
    @Query private var priceOverrides: [PriceOverride]
    @State private var opened: Ingredient?

    var body: some View {
        NavigationStack {
            List {
                if let catalog = store.catalog, let priced = store.catalog(with: priceOverrides) {
                    let have = Set(pantry.map(\.ingredientID))
                    ForEach(IngredientCategory.allCases, id: \.self) { category in
                        let items = catalog.ingredients.values
                            .filter { $0.category == category }
                            .sorted { $0.name.current < $1.name.current }
                        if !items.isEmpty {
                            Section {
                                ForEach(items) { ingredient in
                                    row(ingredient, priced: priced.ingredient(ingredient.id) ?? ingredient, have: have.contains(ingredient.id))
                                }
                            } header: {
                                Text(category.title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Fridge")
            .navigationDestination(item: $opened) { IngredientDetailView(ingredient: $0) }
        }
    }

    /// Tap the name for the ingredient card; the switch is the have / don't have tick.
    private func row(_ ingredient: Ingredient, priced: Ingredient, have: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ingredient.name.current)
                Text(verbatim: "\(Int(priced.packGrams.rounded())) \(String(localized: "g")) · ~\(Int(priced.packPriceUAH.rounded())) ₴")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { opened = ingredient }
            .accessibilityAddTraits(.isButton)
            Toggle(ingredient.name.current, isOn: Binding(
                get: { have },
                set: { setHave($0, ingredientID: ingredient.id) }
            ))
            .labelsHidden()
        }
    }

    private func setHave(_ on: Bool, ingredientID: String) {
        let existing = pantry.filter { $0.ingredientID == ingredientID }
        if on {
            if existing.isEmpty { context.insert(PantryItem(ingredientID: ingredientID)) }
        } else {
            existing.forEach { context.delete($0) }
        }
        context.saveNow()
    }
}
