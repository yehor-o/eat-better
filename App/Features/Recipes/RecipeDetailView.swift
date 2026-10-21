import EatBetterCore
import SwiftData
import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    let catalog: Catalog

    @Environment(\.modelContext) private var context
    @Query private var profiles: [ProfileRecord]
    @State private var loggedAt: Date?
    @State private var cookedAt: Date?

    var body: some View {
        List {
            Section {
                Text("^[\(recipe.servings) serving](inflect: true) · \(recipe.totalMinutes) min")
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
                                // Not a Label: inside a List it pads the icon and pulls the separator inward.
                                HStack(spacing: 4) {
                                    Image(systemName: "timer")
                                    Text("\(minutes) min")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                }
            }

            Section {
                // TODO(T-012): cooking mode with timers and scaling.
                // The confirmation lives in the button itself: a row below it would sit under the tab bar.
                Button {
                    context.insert(MealLogEntry(
                        title: recipe.name.current,
                        recipeID: recipe.id,
                        nutrition: catalog.nutritionPerServing(of: recipe)
                    ))
                    loggedAt = .now
                } label: {
                    if loggedAt == nil {
                        Label("Log 1 serving as eaten", systemImage: "checkmark.circle")
                    } else {
                        Label("Logged. Tap to log 1 more serving", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .sensoryFeedback(.success, trigger: loggedAt)

                if recipe.servings > 1 {
                    Button {
                        context.addCookedPortions(of: recipe, catalog: catalog,
                                                  defaultStorageDays: profiles.first?.defaultStorageDays ?? 7)
                        cookedAt = .now
                    } label: {
                        if cookedAt == nil {
                            Label("Cooked: \(recipe.servings) portions to Ready", systemImage: "frying.pan")
                        } else {
                            Label("Added to \"Ready in the fridge\"", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .disabled(cookedAt != nil)
                    .sensoryFeedback(.success, trigger: cookedAt)
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
        // Unit names may carry their own brackets ("cup (250 ml)"), so no brackets around this part.
        return "\(grams) · ≈ \(count) × \(household.unit.name.current)"
    }
}
