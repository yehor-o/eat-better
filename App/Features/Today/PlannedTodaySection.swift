import EatBetterCore
import SwiftData
import SwiftUI

/// Today's meals from the Plan tab, each one tap away from being eaten or cooked.
struct PlannedTodaySection: View {
    let catalog: Catalog
    /// Presented by the Today screen: a cover attached inside a List section does not show reliably.
    @Binding var cooking: PlanEntry?
    let onLogFood: () -> Void

    @Environment(\.modelContext) private var context
    @Query private var entries: [PlanEntry]
    @Query(sort: \ReadyPortion.expiresAt) private var portions: [ReadyPortion]
    @Query private var myProducts: [MyProduct]

    private var today: [PlanEntry] {
        entries
            .filter { Calendar.current.isDateInToday($0.day) && $0.fill != nil }
            .sorted { PlanSlot(day: 0, meal: $0.meal, number: $0.number) < PlanSlot(day: 0, meal: $1.meal, number: $1.number) }
    }

    var body: some View {
        if !today.isEmpty {
            Section("Planned for today") {
                ForEach(today) { entry in
                    row(entry)
                }
            }
        }
    }

    // MARK: Row

    private func row(_ entry: PlanEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.meal.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: title(of: entry))
                if let kcal = nutrition(of: entry)?.kcal {
                    Text(verbatim: "\(Int(kcal.rounded())) \(String(localized: "kcal"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            action(entry)
        }
        .swipeActions {
            // Eaten without cooking it here (e.g. made it some other way).
            if entry.eatenAt == nil, case .recipe = entry.fill {
                Button("Ate it") { ate(entry) }.tint(.green)
            }
        }
    }

    @ViewBuilder
    private func action(_ entry: PlanEntry) -> some View {
        if entry.eatenAt != nil {
            Label("Eaten", systemImage: "checkmark.circle.fill")
                .labelStyle(.iconOnly)
                .font(.title2)
                .foregroundStyle(.green)
                .accessibilityLabel(Text("Eaten"))
        } else {
            switch entry.fill {
            case .recipe(let id):
                if portions.contains(where: { $0.recipeID == id }) {
                    Button("Ate it") { ate(entry) }.buttonStyle(.bordered)
                } else {
                    Button("Cook") { cooking = entry }
                    .buttonStyle(.borderedProminent)
                }
            case .product:
                Button("Ate it") { ate(entry) }.buttonStyle(.bordered)
            case .outside:
                Button("Log food") {
                    entry.eatenAt = .now
                    context.saveNow()
                    onLogFood()
                }
                .buttonStyle(.bordered)
            case nil:
                EmptyView()
            }
        }
    }

    // MARK: Data

    private func recipe(of entry: PlanEntry) -> Recipe? {
        guard case .recipe(let id) = entry.fill else { return nil }
        return catalog.recipes.first { $0.id == id }
    }

    private func product(of entry: PlanEntry) -> MyProduct? {
        guard case .product(let id) = entry.fill else { return nil }
        return myProducts.first { $0.stableID == id }
    }

    private func title(of entry: PlanEntry) -> String {
        switch entry.fill {
        case .recipe: recipe(of: entry)?.name.current ?? "—"
        case .product: product(of: entry)?.name ?? "—"
        case .outside: String(localized: "Outside food")
        case nil: "—"
        }
    }

    private func nutrition(of entry: PlanEntry) -> Nutrition? {
        if let recipe = recipe(of: entry) { return catalog.nutritionPerServing(of: recipe) }
        return product(of: entry)?.planProduct.portion
    }

    /// Takes a ready portion of the dish when there is one (soonest to expire first), otherwise logs
    /// one serving; products log one pack.
    private func ate(_ entry: PlanEntry) {
        switch entry.fill {
        case .recipe(let id):
            if let portion = portions.first(where: { $0.recipeID == id }) {
                context.insert(MealLogEntry(title: portion.title, recipeID: portion.recipeID, nutrition: portion.nutrition))
                context.delete(portion)
            } else if let recipe = recipe(of: entry) {
                context.insert(MealLogEntry(title: recipe.name.current, recipeID: recipe.id, nutrition: catalog.nutritionPerServing(of: recipe)))
            }
        case .product:
            if let product = product(of: entry) {
                context.insert(MealLogEntry(title: product.name, nutrition: product.planProduct.portion))
            }
        case .outside, nil:
            break
        }
        entry.eatenAt = .now
        context.saveNow()
    }
}

/// Cooking mode for a planned meal: marks the plan entry cooked (and eaten, for "Eat now").
struct PlannedCookingView: View {
    let entry: PlanEntry
    let recipe: Recipe
    let catalog: Catalog

    @Environment(\.modelContext) private var context
    @State private var portions: Int

    init(entry: PlanEntry, recipe: Recipe, catalog: Catalog) {
        self.entry = entry
        self.recipe = recipe
        self.catalog = catalog
        _portions = State(initialValue: recipe.servings)
    }

    var body: some View {
        CookingModeView(recipe: recipe, catalog: catalog, portions: $portions) { ateOne in
            entry.cookedAt = .now
            if ateOne { entry.eatenAt = .now }
            context.saveNow()
        }
    }
}
