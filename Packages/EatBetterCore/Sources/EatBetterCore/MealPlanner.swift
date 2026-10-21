import Foundation

/// The days a plan covers: from the next shopping day until the one after it (D-017).
public enum ShoppingSchedule {
    /// - Parameter weekdays: shopping days as `Calendar` weekdays (1 = Sunday … 7 = Saturday).
    ///   Empty means "no fixed days": the plan starts today and covers `fallbackDays`.
    public static func period(
        from today: Date,
        weekdays: Set<Int>,
        calendar: Calendar = .current,
        fallbackDays: Int = 3
    ) -> (start: Date, days: Int) {
        let start = calendar.startOfDay(for: today)
        guard !weekdays.isEmpty else { return (start, fallbackDays) }
        let first = (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
            .first { weekdays.contains(calendar.component(.weekday, from: $0)) }!
        let days = (1...7).first { offset in
            weekdays.contains(calendar.component(.weekday, from: calendar.date(byAdding: .day, value: offset, to: first)!))
        }!
        return (first, days)
    }
}

/// One meal on one day of a plan; `day` counts from the plan's first day.
public struct PlanSlot: Hashable, Comparable, Sendable {
    public var day: Int
    public var meal: MealType

    public init(day: Int, meal: MealType) {
        self.day = day
        self.meal = meal
    }

    public static func < (a: PlanSlot, b: PlanSlot) -> Bool {
        (a.day, a.meal.order) < (b.day, b.meal.order)
    }
}

public enum SlotFill: Hashable, Sendable {
    case recipe(String)
    /// Food from family, a café… Nothing to buy or cook.
    case outside
}

/// One cooking of a recipe that feeds one or more slots (cook-ahead).
public struct PlanBatch: Hashable, Sendable {
    public var recipe: Recipe
    /// Slots eaten from this batch; the first one is the day it is cooked.
    public var slots: [PlanSlot]

    public var cookSlot: PlanSlot { slots[0] }
}

public struct ShoppingPlan: Sendable {
    public var list: ShoppingList
    /// Ingredients ticked as "have" that the plan uses, with the amount needed: the fridge has no
    /// quantities (D-006), so the owner checks these at home.
    public var checkAtHome: [(ingredient: Ingredient, grams: Double)]
}

public enum MealPlanner {
    public static let defaultMeals: [MealType] = [.breakfast, .lunch, .dinner]

    public struct Request: Sendable {
        public var days: Int
        public var meals: [MealType]
        /// Slots the owner chose by hand (a dish or "outside food"); auto-fill keeps them.
        public var fixed: [PlanSlot: SlotFill]
        public var available: Set<String>
        public var prices: [String: Double]
        public var dailyTarget: Nutrition?
        /// Days a cooked batch is eaten from when the recipe does not say otherwise.
        public var defaultStorageDays: Int

        public init(
            days: Int,
            meals: [MealType] = MealPlanner.defaultMeals,
            fixed: [PlanSlot: SlotFill] = [:],
            available: Set<String> = [],
            prices: [String: Double] = [:],
            dailyTarget: Nutrition? = nil,
            defaultStorageDays: Int = 3
        ) {
            self.days = days
            self.meals = meals
            self.fixed = fixed
            self.available = available
            self.prices = prices
            self.dailyTarget = dailyTarget
            self.defaultStorageDays = defaultStorageDays
        }

        var slots: [PlanSlot] {
            (0..<days).flatMap { day in meals.map { PlanSlot(day: day, meal: $0) } }.sorted()
        }
    }

    /// Fills every slot that is not fixed. Greedy: a cooked batch keeps feeding later slots of the
    /// same kind while it lasts; otherwise picks the recipe with the best mix of protein, reuse of
    /// what is at home or already on the list, low extra cost and variety.
    public static func fill(_ request: Request, catalog: Catalog) -> [PlanSlot: SlotFill] {
        var fills = request.fixed
        for slot in request.slots where fills[slot] == nil {
            // Eat from a batch that is already planned, unless that dish is already on this day.
            let open = batches(for: fills, catalog: catalog, defaultStorageDays: request.defaultStorageDays)
                .filter { batch in
                    batch.slots.count < batch.recipe.servings
                        && MealSuggester.fits(batch.recipe, meal: slot.meal)
                        && slot.day - batch.cookSlot.day < storageDays(batch.recipe, request.defaultStorageDays)
                        && batch.cookSlot < slot
                        && !fills.contains { $0.key.day == slot.day && $0.value == .recipe(batch.recipe.id) }
                }
            if let batch = open.first {
                fills[slot] = .recipe(batch.recipe.id)
                continue
            }
            let candidates = catalog.recipes.filter { MealSuggester.fits($0, meal: slot.meal) }
            let best = candidates.max { a, b in
                let sa = score(a, slot: slot, fills: fills, request: request, catalog: catalog)
                let sb = score(b, slot: slot, fills: fills, request: request, catalog: catalog)
                return (sa, b.id) < (sb, a.id)
            }
            if let best { fills[slot] = .recipe(best.id) }
        }
        return fills
    }

    /// Groups the planned dishes into cookings: a slot joins the latest batch of the same recipe
    /// while it has portions left and is still within its storage days; otherwise it starts a new one.
    public static func batches(for fills: [PlanSlot: SlotFill], catalog: Catalog, defaultStorageDays: Int = 3) -> [PlanBatch] {
        var result: [PlanBatch] = []
        for (slot, fill) in fills.sorted(by: { $0.key < $1.key }) {
            guard case .recipe(let id) = fill, let recipe = catalog.recipes.first(where: { $0.id == id }) else { continue }
            if let index = result.lastIndex(where: { $0.recipe.id == id }),
               result[index].slots.count < recipe.servings,
               slot.day - result[index].cookSlot.day < storageDays(recipe, defaultStorageDays) {
                result[index].slots.append(slot)
            } else {
                result.append(PlanBatch(recipe: recipe, slots: [slot]))
            }
        }
        return result
    }

    /// Nutrition of what is planned for one day (outside food is not counted).
    public static func nutrition(day: Int, fills: [PlanSlot: SlotFill], catalog: Catalog) -> Nutrition {
        fills.filter { $0.key.day == day }.reduce(.zero) { sum, entry in
            guard case .recipe(let id) = entry.value, let recipe = catalog.recipes.first(where: { $0.id == id }) else { return sum }
            return sum + catalog.nutritionPerServing(of: recipe)
        }
    }

    public static func shopping(
        for batches: [PlanBatch],
        catalog: Catalog,
        available: Set<String>,
        prices: [String: Double] = [:]
    ) -> ShoppingPlan {
        let planned = batches.map { PlannedBatch(recipe: $0.recipe) }
        var atHome: [String: Double] = [:]
        for batch in planned {
            for item in batch.recipe.ingredients where !item.optional && available.contains(item.ingredientID) {
                atHome[item.ingredientID, default: 0] += item.grams * batch.scale
            }
        }
        let check = atHome.compactMap { id, grams in catalog.ingredient(id).map { (ingredient: $0, grams: grams) } }
            .sorted { $0.ingredient.id < $1.ingredient.id }
        return ShoppingPlan(
            list: ShoppingPlanner.list(for: planned, catalog: catalog, available: available, prices: prices),
            checkAtHome: check
        )
    }

    // MARK: Scoring

    static func storageDays(_ recipe: Recipe, _ fallback: Int) -> Int {
        recipe.storageDays ?? fallback
    }

    private static func score(_ recipe: Recipe, slot: PlanSlot, fills: [PlanSlot: SlotFill], request: Request, catalog: Catalog) -> Double {
        let used = fills.values.filter { $0 == .recipe(recipe.id) }.count
        let onList = Set(fills.values.compactMap { fill -> String? in
            if case .recipe(let id) = fill { id } else { nil }
        }.compactMap { id in catalog.recipes.first { $0.id == id } }.flatMap { $0.ingredients.map(\.ingredientID) })

        let required = recipe.ingredients.filter { !$0.optional }
        let covered = required.filter { request.available.contains($0.ingredientID) || onList.contains($0.ingredientID) }
        let extraCost = required.filter { !request.available.contains($0.ingredientID) && !onList.contains($0.ingredientID) }
            .compactMap { catalog.ingredient($0.ingredientID) }
            .reduce(0) { $0 + (request.prices[$1.id] ?? $1.packPriceUAH) }

        let protein = catalog.nutritionPerServing(of: recipe).protein
        let proteinPerMeal = (request.dailyTarget?.protein ?? 126) / Double(max(request.meals.count, 1))

        var score = min(protein / proteinPerMeal, 1.2) * 2
        score += required.isEmpty ? 1 : Double(covered.count) / Double(required.count)
        score -= extraCost / 150
        score -= Double(used) * 1.5
        // Not the same dish twice in one day.
        if fills.contains(where: { $0.key.day == slot.day && $0.value == .recipe(recipe.id) }) { score -= 3 }
        return score
    }
}

extension MealType {
    var order: Int {
        switch self {
        case .breakfast: 0
        case .lunch: 1
        case .snack: 2
        case .dinner: 3
        }
    }
}
