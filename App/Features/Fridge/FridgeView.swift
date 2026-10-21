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
    @State private var search = ""
    @State private var show: Shown = .all
    @State private var category: IngredientCategory?

    enum Shown: Hashable {
        case all, have, missing
    }

    var body: some View {
        NavigationStack {
            List {
                if let catalog = store.catalog, let priced = store.catalog(with: priceOverrides) {
                    let have = Set(pantry.map(\.ingredientID))
                    let shown = catalog.ingredients.values.filter { matches($0, have: have) }
                    if shown.isEmpty {
                        ContentUnavailableView.search(text: search)
                    }
                    ForEach(IngredientCategory.allCases, id: \.self) { category in
                        let items = shown
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
            .searchable(text: $search, prompt: Text("Product or category"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { filterMenu }
            }
            .navigationDestination(item: $opened) { IngredientDetailView(ingredient: $0) }
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker("Show", selection: $show) {
                Text("Everything").tag(Shown.all)
                Text("At home").tag(Shown.have)
                Text("Not at home").tag(Shown.missing)
            }
            Picker("Category", selection: $category) {
                Text("All categories").tag(IngredientCategory?.none)
                ForEach(IngredientCategory.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
            }
        } label: {
            let isFiltered = show != .all || category != nil
            Label("Filter", systemImage: isFiltered ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    /// Search looks at the product and its category name, in the current language.
    private func matches(_ ingredient: Ingredient, have: Set<String>) -> Bool {
        if let category, ingredient.category != category { return false }
        switch show {
        case .all: break
        case .have: if !have.contains(ingredient.id) { return false }
        case .missing: if have.contains(ingredient.id) { return false }
        }
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return ingredient.name.current.localizedCaseInsensitiveContains(query)
            || ingredient.category.localizedName.localizedCaseInsensitiveContains(query)
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
