import EatBetterCore
import SwiftData
import SwiftUI

/// "What should I eat now?" (spec #7): one suggestion at a time, "Another option" moves on.
struct SuggestionView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var pantry: [PantryItem]
    @Query private var priceOverrides: [PriceOverride]
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \MealLogEntry.date, order: .reverse) private var log: [MealLogEntry]
    @Query(sort: \ReadyPortion.expiresAt) private var portions: [ReadyPortion]

    @State private var index = 0
    /// Computed once when the sheet opens, so eating or logging does not reshuffle the list.
    @State private var suggestions: [MealSuggestion]?

    var body: some View {
        NavigationStack {
            Group {
                if let catalog = store.catalog(with: priceOverrides), let suggestions {
                    if suggestions.isEmpty {
                        ContentUnavailableView(
                            "Nothing to suggest yet",
                            systemImage: "refrigerator",
                            description: Text("Tick what you have in the Fridge tab, or log food that is already cooked.")
                        )
                    } else {
                        card(suggestions[index % suggestions.count], position: index % suggestions.count + 1,
                             of: suggestions.count, catalog: catalog)
                    }
                } else {
                    // Also gives onAppear a view to fire on.
                    ProgressView()
                }
            }
            .navigationTitle("What to eat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                if suggestions == nil, let catalog = store.catalog(with: priceOverrides) { suggestions = makeSuggestions(catalog: catalog) }
            }
        }
    }

    private func card(_ suggestion: MealSuggestion, position: Int, of count: Int, catalog: Catalog) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(suggestion.title.current)
                        .font(.title2.bold())
                    subtitle(suggestion, catalog: catalog)
                        .font(.subheadline)
                    Text(verbatim: suggestion.reasons.map(reasonText).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("One portion") {
                NutritionRows(value: suggestion.nutrition)
            }

            Section {
                switch suggestion.kind {
                case .ready(let id):
                    Button("Eat it now", systemImage: "checkmark.circle") {
                        if let portion = readyPortion(id: id) {
                            context.insert(MealLogEntry(title: portion.title, recipeID: portion.recipeID, nutrition: portion.nutrition))
                            context.delete(portion)
                        }
                        dismiss()
                    }
                case .cookNow(let recipeID), .buyFirst(let recipeID, _):
                    if let recipe = catalog.recipes.first(where: { $0.id == recipeID }) {
                        NavigationLink {
                            RecipeDetailView(recipe: recipe, catalog: catalog)
                        } label: {
                            Label("Open the recipe", systemImage: "book")
                        }
                    }
                }
                if count > 1 {
                    Button {
                        withAnimation { index += 1 }
                    } label: {
                        Label("Another option (\(position) of \(count))", systemImage: "arrow.trianglehead.2.clockwise")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func subtitle(_ suggestion: MealSuggestion, catalog: Catalog) -> some View {
        switch suggestion.kind {
        case .ready(let id):
            if let portion = readyPortion(id: id) {
                Text("Ready in the fridge · eat by \(portion.expiresAt, format: .dateTime.day().month())")
                    .foregroundStyle(.green)
            }
        case .cookNow:
            Text("You have everything · \(suggestion.minutes ?? 0) min")
                .foregroundStyle(.green)
        case .buyFirst(_, let missing):
            let cost = missing.reduce(0) { $0 + $1.packPriceUAH }
            Text("Buy first: \(missing.map(\.name.current).joined(separator: ", ")) · ~\(Int(cost.rounded())) ₴")
                .foregroundStyle(.orange)
        }
    }

    private func reasonText(_ reason: MealSuggestion.Reason) -> String {
        switch reason {
        case .alreadyCooked: String(localized: "already cooked")
        case .eatSoon: String(localized: "best eaten soon")
        case .fitsMeal(.breakfast): String(localized: "good for breakfast")
        case .fitsMeal(.lunch): String(localized: "good for lunch")
        case .fitsMeal(.dinner): String(localized: "good for dinner")
        case .fitsMeal(.snack): String(localized: "good as a snack")
        case .proteinRich: String(localized: "rich in protein")
        case .quick: String(localized: "quick")
        }
    }

    // MARK: Data

    private func makeSuggestions(catalog: Catalog) -> [MealSuggestion] {
        let today = log.filter { Calendar.current.isDateInToday($0.date) }
        let dayAgo = Date.now.addingTimeInterval(-24 * 3600)
        let context = MealSuggester.Context(
            now: .now,
            ready: readyItems,
            pantry: PantryMatcher.match(catalog: catalog, available: Set(pantry.map(\.ingredientID))),
            eaten: today.reduce(Nutrition.zero) { $0 + $1.nutrition },
            target: profiles.first.map { DailyTargets.targets(for: $0.bodyProfile) },
            recentRecipeIDs: Set(log.filter { $0.date > dayAgo }.compactMap(\.recipeID))
        )
        return MealSuggester.suggestions(context, catalog: catalog)
    }

    /// One item per food: identical portions would only repeat the same suggestion.
    private var readyItems: [ReadyItem] {
        var seen = Set<String>()
        return portions.filter { seen.insert($0.title).inserted }.map {
            ReadyItem(id: $0.title, title: $0.title, nutrition: $0.nutrition, expiresAt: $0.expiresAt)
        }
    }

    private func readyPortion(id: String) -> ReadyPortion? {
        portions.first { $0.title == id }
    }

}
