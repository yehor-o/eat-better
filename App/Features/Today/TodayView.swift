import EatBetterCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \MealLogEntry.date, order: .reverse) private var log: [MealLogEntry]
    @Query(sort: \ReadyPortion.expiresAt) private var portions: [ReadyPortion]

    private var todayEntries: [MealLogEntry] {
        log.filter { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // TODO(T-010): "What should I eat now?" suggestion engine.
                    Button("What should I eat now?", systemImage: "sparkles") {}
                        .disabled(true)
                }

                Section("Today") {
                    let eaten = todayEntries.reduce(Nutrition.zero) { $0 + $1.nutrition }
                    NutritionRows(value: eaten, target: profiles.first.map { DailyTargets.targets(for: $0.bodyProfile) })
                    if profiles.isEmpty {
                        Text("Set up your profile in Settings to see daily targets.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !portions.isEmpty, let catalog = store.catalog {
                    Section("Ready in the fridge") {
                        ForEach(portions) { portion in
                            if let recipe = catalog.recipes.first(where: { $0.id == portion.recipeID }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(recipe.name.current)
                                        Text("Eat by \(portion.expiresAt, format: .dateTime.day().month())")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Ate it") { eat(portion, recipe: recipe, catalog: catalog) }
                                        .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                }

                Section("Eaten today") {
                    if todayEntries.isEmpty {
                        Text("Nothing logged yet.").foregroundStyle(.secondary)
                    }
                    ForEach(todayEntries) { entry in
                        LabeledContent(entry.title) {
                            Text(verbatim: "\(Int(entry.kcal.rounded())) \(String(localized: "kcal"))")
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(todayEntries[index]) }
                    }
                }
            }
            .navigationTitle("Today")
        }
    }

    private func eat(_ portion: ReadyPortion, recipe: Recipe, catalog: Catalog) {
        context.insert(MealLogEntry(
            title: recipe.name.current,
            recipeID: recipe.id,
            nutrition: catalog.nutritionPerServing(of: recipe)
        ))
        context.delete(portion)
    }
}
