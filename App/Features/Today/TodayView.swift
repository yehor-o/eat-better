import EatBetterCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \MealLogEntry.date, order: .reverse) private var log: [MealLogEntry]
    @Query(sort: \ReadyPortion.expiresAt) private var portions: [ReadyPortion]
    @State private var isLoggingFood = false
    @State private var isSuggesting = false

    private var todayEntries: [MealLogEntry] {
        log.filter { Calendar.current.isDateInToday($0.date) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("What should I eat now?", systemImage: "sparkles") { isSuggesting = true }
                    Button("Log food", systemImage: "plus.circle") { isLoggingFood = true }
                }

                Section("Today") {
                    let eaten = todayEntries.reduce(Nutrition.zero) { $0 + $1.nutrition }
                    NutritionRows(value: eaten, target: profiles.first.map { DailyTargets.targets(for: $0.bodyProfile) })
                    if profiles.isEmpty {
                        Text("Set up your profile in Settings to see daily targets.")
                            .foregroundStyle(.secondary)
                    }
                }

                if !portions.isEmpty {
                    Section("Ready in the fridge") {
                        ForEach(portionGroups, id: \.first!.persistentModelID) { group in
                            let portion = group[0]
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(group.count > 1 ? "\(portion.title) ×\(group.count)" : portion.title)
                                    Text("Eat by \(portion.expiresAt, format: .dateTime.day().month())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Ate it") { eat(portion) }
                                    .buttonStyle(.bordered)
                            }
                            .swipeActions {
                                Button("Delete", role: .destructive) { context.delete(portion) }
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
            .sheet(isPresented: $isLoggingFood) { LogFoodView() }
            .sheet(isPresented: $isSuggesting) { SuggestionView() }
        }
    }

    /// Identical portions (same food, same eat-by day) shown as one row with a count.
    private var portionGroups: [[ReadyPortion]] {
        var groups: [[ReadyPortion]] = []
        for portion in portions {
            if let index = groups.firstIndex(where: {
                $0[0].title == portion.title && Calendar.current.isDate($0[0].expiresAt, inSameDayAs: portion.expiresAt)
            }) {
                groups[index].append(portion)
            } else {
                groups.append([portion])
            }
        }
        return groups
    }

    private func eat(_ portion: ReadyPortion) {
        context.insert(MealLogEntry(title: portion.title, recipeID: portion.recipeID, nutrition: portion.nutrition))
        context.delete(portion)
    }
}
