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
    @State private var isCooking = false
    /// How many portions to cook; the ingredient amounts follow it.
    @State private var portions: Int

    init(recipe: Recipe, catalog: Catalog) {
        self.recipe = recipe
        self.catalog = catalog
        _portions = State(initialValue: recipe.servings)
    }

    private var cooked: Recipe { recipe.scaled(toServings: portions) }

    var body: some View {
        List {
            Section {
                Text("\(recipe.totalMinutes) min")
                    .foregroundStyle(.secondary)
                PortionStepper(portions: $portions)
                Button("Start cooking", systemImage: "play.circle.fill") { isCooking = true }
                    .font(.headline)
                // Already cooked without cooking mode: put the portions straight into Ready.
                Button {
                    context.addCookedPortions(of: cooked, catalog: catalog,
                                              defaultStorageDays: profiles.first?.defaultStorageDays ?? 7)
                    cookedAt = .now
                } label: {
                    if cookedAt == nil {
                        Label("Cooked: \(portions) portions to Ready", systemImage: "frying.pan")
                    } else {
                        Label("Added to \"Ready in the fridge\"", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .disabled(cookedAt != nil)
                .sensoryFeedback(.success, trigger: cookedAt)
                .onChange(of: portions) { cookedAt = nil }
            }

            Section("Per serving") {
                NutritionRows(value: catalog.nutritionPerServing(of: recipe))
            }

            Section("Ingredients") {
                ForEach(cooked.ingredients, id: \.ingredientID) { item in
                    if let ingredient = catalog.ingredient(item.ingredientID) {
                        LabeledContent {
                            Text(verbatim: catalog.amountText(ingredientID: item.ingredientID, grams: item.grams))
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
                // The confirmation lives in the button itself: a row below it would sit under the tab bar.
                Button {
                    context.insert(MealLogEntry(
                        title: recipe.name.current,
                        recipeID: recipe.id,
                        nutrition: catalog.nutritionPerServing(of: recipe)
                    ))
                    context.saveNow()
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

            }
        }
        .navigationTitle(recipe.name.current)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isCooking) {
            CookingModeView(recipe: recipe, catalog: catalog, portions: $portions)
        }
    }
}

/// Number of portions to cook, 1–12.
struct PortionStepper: View {
    @Binding var portions: Int

    var body: some View {
        Stepper(value: $portions, in: 1...12) {
            Text("Portions: \(portions)")
        }
    }
}
