import EatBetterCore
import SwiftData
import SwiftUI

/// Plan until the next shopping trip (D-017): days × meals, auto-fill, hand edits, shopping list.
struct PlanView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @AppStorage("shoppingWeekdays") private var weekdaysRaw = ""
    @Query private var entries: [PlanEntry]
    @Query private var pantry: [PantryItem]
    @Query private var priceOverrides: [PriceOverride]
    @Query private var profiles: [ProfileRecord]

    @State private var picking: PlanSlot?

    var body: some View {
        NavigationStack {
            Group {
                if let catalog = store.catalog {
                    plan(catalog: catalog)
                } else {
                    ContentUnavailableView("Could not load recipes", systemImage: "exclamationmark.triangle")
                }
            }
            .navigationTitle("Plan")
        }
    }

    private func plan(catalog: Catalog) -> some View {
        let fills = currentFills
        let batches = MealPlanner.batches(for: fills, catalog: catalog, defaultStorageDays: storageDays)
        // A cooked batch needs nothing more from the store.
        let toCook = batches.filter { !cookEntryCooked($0) }
        let shopping = MealPlanner.shopping(for: toCook, catalog: catalog, available: available, prices: prices)
        let target = profiles.first.map { DailyTargets.targets(for: $0.bodyProfile) }

        return List {
            Section {
                NavigationLink {
                    ShoppingDaysView(weekdaysRaw: $weekdaysRaw)
                } label: {
                    LabeledContent("Shopping days") {
                        Text(verbatim: weekdayNames.isEmpty ? String(localized: "Not set") : weekdayNames)
                    }
                }
                LabeledContent("Plan for") {
                    Text(verbatim: periodText)
                }
                Button("Fill the plan", systemImage: "wand.and.stars") { fill(catalog: catalog) }
            } footer: {
                Text("Dishes you pick by hand and cooked dishes stay when you fill again.")
            }

            ForEach(0..<period.days, id: \.self) { day in
                Section {
                    ForEach(MealPlanner.defaultMeals, id: \.self) { meal in
                        let slot = PlanSlot(day: day, meal: meal)
                        slotRow(slot, fill: fills[slot], batch: batches.first { $0.slots.contains(slot) }, catalog: catalog)
                    }
                } header: {
                    Text(date(of: day), format: .dateTime.weekday(.wide).day().month())
                } footer: {
                    dayFooter(MealPlanner.nutrition(day: day, fills: fills, catalog: catalog), target: target,
                              hasOutside: fills.contains { $0.key.day == day && $0.value == .outside })
                }
            }

            Section {
                NavigationLink {
                    ShoppingListView(plan: shopping, catalog: catalog)
                } label: {
                    LabeledContent {
                        Text(verbatim: "~\(Int(shopping.list.totalUAH.rounded())) ₴")
                    } label: {
                        Label("Shopping list", systemImage: "cart")
                    }
                }
            }
        }
        .sheet(item: $picking) { slot in
            RecipePickerView(meal: slot.meal, catalog: catalog) { recipe in
                set(slot, recipeID: recipe.id)
            }
        }
    }

    // MARK: Rows

    private func slotRow(_ slot: PlanSlot, fill: SlotFill?, batch: PlanBatch?, catalog: Catalog) -> some View {
        let entry = entry(for: slot)
        let isCookSlot = batch?.cookSlot == slot
        return Menu {
            Button("Choose a dish", systemImage: "list.bullet") { picking = slot }
            Button("Outside food", systemImage: "takeoutbag.and.cup.and.straw") { setOutside(slot) }
            if entry?.isManual == true {
                Button("Let the app choose", systemImage: "wand.and.stars") { clear(slot) }
            }
            if isCookSlot, let batch, entry?.cookedAt == nil {
                Button("Cooked: \(batch.recipe.servings) portions to Ready", systemImage: "frying.pan") {
                    context.addCookedPortions(of: batch.recipe, catalog: catalog, defaultStorageDays: storageDays)
                    entry?.cookedAt = .now
                    context.saveNow()
                }
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(slot.meal.title)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    switch fill {
                    case .recipe:
                        Text(batch?.recipe.name.current ?? "")
                            .foregroundStyle(.primary)
                    case .outside:
                        Text("Outside food").foregroundStyle(.primary)
                    case nil:
                        Text(verbatim: "—").foregroundStyle(.secondary)
                    }
                    if let batch, case .recipe = fill {
                        batchNote(batch, slot: slot, cooked: entry?.cookedAt != nil || cookEntryCooked(batch))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if entry?.isManual == true {
                    Image(systemName: "pin.fill").font(.caption).foregroundStyle(.secondary)
                }
            }
            .multilineTextAlignment(.leading)
        }
        // A menu label is tinted like a button; keep the row looking like plain text.
        .tint(.primary)
    }

    @ViewBuilder
    private func batchNote(_ batch: PlanBatch, slot: PlanSlot, cooked: Bool) -> some View {
        Group {
            if batch.cookSlot == slot {
                if cooked {
                    Label("Cooked", systemImage: "checkmark.circle").foregroundStyle(.green)
                } else if batch.slots.count > 1 {
                    Label("Cook \(batch.recipe.servings) portions · \(batch.recipe.totalMinutes) min", systemImage: "frying.pan")
                        .foregroundStyle(.orange)
                } else {
                    Label("Cook · \(batch.recipe.totalMinutes) min", systemImage: "frying.pan")
                        .foregroundStyle(.orange)
                }
            } else {
                Label("From the cooked batch", systemImage: "takeoutbag.and.cup.and.straw")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func dayFooter(_ n: Nutrition, target: Nutrition?, hasOutside: Bool) -> some View {
        var text = String(localized: "≈ \(Int(n.kcal.rounded())) kcal · \(Int(n.protein.rounded())) g protein")
        if let target {
            text += " " + String(localized: "of \(Int(target.kcal.rounded())) / \(Int(target.protein.rounded()))")
        }
        if hasOutside {
            text += " · " + String(localized: "plus outside food")
        }
        return Text(verbatim: text)
    }

    // MARK: Plan data

    private var weekdays: Set<Int> {
        Set(weekdaysRaw.split(separator: ",").compactMap { Int($0) })
    }

    private var period: (start: Date, days: Int) {
        ShoppingSchedule.period(from: .now, weekdays: weekdays)
    }

    private func date(of day: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: day, to: period.start) ?? period.start
    }

    private var periodText: String {
        let start = period.start
        let end = date(of: period.days - 1)
        let style = Date.FormatStyle.dateTime.day().month()
        return "\(start.formatted(style)) – \(end.formatted(style)) · " + String(localized: "^[\(period.days) day](inflect: true)")
    }

    private var weekdayNames: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        return weekdays.sorted { ($0 + 5) % 7 < ($1 + 5) % 7 }.map { symbols[$0 - 1] }.joined(separator: ", ")
    }

    private func dayIndex(of entry: PlanEntry) -> Int? {
        let days = Calendar.current.dateComponents([.day], from: period.start, to: entry.day).day
        return days.flatMap { (0..<period.days).contains($0) ? $0 : nil }
    }

    private func entry(for slot: PlanSlot) -> PlanEntry? {
        entries.first { $0.meal == slot.meal && dayIndex(of: $0) == slot.day }
    }

    private var currentFills: [PlanSlot: SlotFill] {
        var fills: [PlanSlot: SlotFill] = [:]
        for entry in entries {
            guard let day = dayIndex(of: entry), let fill = entry.fill else { continue }
            fills[PlanSlot(day: day, meal: entry.meal)] = fill
        }
        return fills
    }

    private func cookEntryCooked(_ batch: PlanBatch) -> Bool {
        entry(for: batch.cookSlot)?.cookedAt != nil
    }

    private var available: Set<String> { Set(pantry.map(\.ingredientID)) }

    private var prices: [String: Double] {
        Dictionary(priceOverrides.map { ($0.ingredientID, $0.packPriceUAH) }, uniquingKeysWith: { a, _ in a })
    }

    private var storageDays: Int { profiles.first?.defaultStorageDays ?? 7 }

    // MARK: Edits

    private func fill(catalog: Catalog) {
        // Entries from past plans are no longer needed.
        for entry in entries where entry.day < period.start { context.delete(entry) }
        var fixed: [PlanSlot: SlotFill] = [:]
        for entry in entries {
            guard let day = dayIndex(of: entry), let fill = entry.fill else { continue }
            if entry.isManual || entry.cookedAt != nil {
                fixed[PlanSlot(day: day, meal: entry.meal)] = fill
            } else {
                context.delete(entry)
            }
        }
        let request = MealPlanner.Request(
            days: period.days, fixed: fixed, available: available, prices: prices,
            dailyTarget: profiles.first.map { DailyTargets.targets(for: $0.bodyProfile) },
            defaultStorageDays: storageDays
        )
        for (slot, fill) in MealPlanner.fill(request, catalog: catalog) where fixed[slot] == nil {
            guard case .recipe(let id) = fill else { continue }
            context.insert(PlanEntry(day: date(of: slot.day), meal: slot.meal, recipeID: id, isManual: false))
        }
        context.saveNow()
    }

    private func set(_ slot: PlanSlot, recipeID: String) {
        clear(slot)
        context.insert(PlanEntry(day: date(of: slot.day), meal: slot.meal, recipeID: recipeID, isManual: true))
        context.saveNow()
    }

    private func setOutside(_ slot: PlanSlot) {
        clear(slot)
        context.insert(PlanEntry(day: date(of: slot.day), meal: slot.meal, recipeID: nil, isOutside: true, isManual: true))
        context.saveNow()
    }

    private func clear(_ slot: PlanSlot) {
        if let entry = entry(for: slot) { context.delete(entry) }
    }
}

extension PlanSlot: @retroactive Identifiable {
    public var id: String { "\(day)-\(meal.rawValue)" }
}

/// Weekdays the owner usually goes shopping.
struct ShoppingDaysView: View {
    @Binding var weekdaysRaw: String

    var body: some View {
        let symbols = Calendar.current.weekdaySymbols
        let selected = Set(weekdaysRaw.split(separator: ",").compactMap { Int($0) })
        List {
            Section {
                // Monday first.
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                    Button {
                        var new = selected
                        if new.contains(weekday) { new.remove(weekday) } else { new.insert(weekday) }
                        weekdaysRaw = new.sorted().map(String.init).joined(separator: ",")
                    } label: {
                        HStack {
                            Text(verbatim: symbols[weekday - 1].capitalized).foregroundStyle(.primary)
                            Spacer()
                            if selected.contains(weekday) { Image(systemName: "checkmark") }
                        }
                    }
                }
            } footer: {
                Text("The plan runs from the next shopping day to the one after it. With no days set it covers 3 days from today.")
            }
        }
        .navigationTitle("Shopping days")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Pick a dish for one slot; dishes that fit the meal come first.
struct RecipePickerView: View {
    let meal: MealType
    let catalog: Catalog
    let onPick: (Recipe) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let fitting = catalog.recipes.filter { MealSuggester.fits($0, meal: meal) && !$0.isOccasional }
        let special = catalog.recipes.filter { MealSuggester.fits($0, meal: meal) && $0.isOccasional }
        let others = catalog.recipes.filter { !MealSuggester.fits($0, meal: meal) }
        NavigationStack {
            List {
                Section { rows(fitting) } header: { Text(meal.title) }
                if !special.isEmpty {
                    Section {
                        rows(special)
                    } header: {
                        Text("Special dishes")
                    } footer: {
                        Text("The plan never adds these on its own.")
                    }
                }
                if !others.isEmpty {
                    Section("Other dishes") { rows(others) }
                }
            }
            .navigationTitle("Choose a dish")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func rows(_ recipes: [Recipe]) -> some View {
        ForEach(recipes) { recipe in
            Button {
                onPick(recipe)
                dismiss()
            } label: {
                RecipeRow(recipe: recipe, catalog: catalog).foregroundStyle(.primary)
            }
        }
    }
}
