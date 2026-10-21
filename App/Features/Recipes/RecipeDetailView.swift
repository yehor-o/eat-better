import EatBetterCore
import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let catalog: Catalog

    @Environment(\.modelContext) private var context
    @State private var loggedAt: Date?

    var body: some View {
        List {
            Section {
                Text("\(recipe.servings) servings · \(recipe.totalMinutes) min")
                    .foregroundStyle(.secondary)
            }

            Section("Per serving") {
                NutritionRows(value: catalog.nutritionPerServing(of: recipe))
            }

            Section("Ingredients") {
                ForEach(recipe.ingredients, id: \.ingredientID) { item in
                    if let ingredient = catalog.ingredient(item.ingredientID) {
                        LabeledContent {
                            Text(verbatim: amountText(item))
                        } label: {
                            Text(verbatim: ingredient.name.current + (item.optional ? " " + String(localized: "(optional)") : ""))
                        }
                    }
                }
            }

            Section("Steps") {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: "\(index + 1).").bold()
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: step.text.current)
                            if let minutes = step.timerMinutes {
                                Label("\(minutes) min", systemImage: "timer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section {
                // TODO(T-012): cooking mode with timers and scaling; T-013: "cooked" → ready portions.
                Button("Log 1 serving as eaten", systemImage: "checkmark.circle") {
                    context.insert(MealLogEntry(
                        title: recipe.name.current,
                        recipeID: recipe.id,
                        nutrition: catalog.nutritionPerServing(of: recipe)
                    ))
                    loggedAt = .now
                }
                if loggedAt != nil {
                    Text("Logged.").foregroundStyle(.green)
                }
            }
        }
        .navigationTitle(recipe.name.current)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func amountText(_ item: RecipeIngredient) -> String {
        let grams = "\(Int(item.grams.rounded())) \(String(localized: "g"))"
        guard let household = catalog.householdAmount(ingredientID: item.ingredientID, grams: item.grams) else {
            return grams
        }
        let count = household.count.formatted(.number.precision(.fractionLength(0...1)))
        return "\(grams) (≈ \(count) × \(household.unit.name.current))"
    }
}
