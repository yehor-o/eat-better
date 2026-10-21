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
    /// 1 for a day's second snack (after dinner); 0 for everything else.
    public var number: Int

    public init(day: Int, meal: MealType, number: Int = 0) {
        self.day = day
        self.meal = meal
        self.number = number
    }

    /// Order within a day: breakfast, lunch, snack, dinner, second snack.
    var position: Int { number > 0 ? 10 + number : meal.order * 2 }

    public static func < (a: PlanSlot, b: PlanSlot) -> Bool {
        (a.day, a.position) < (b.day, b.position)
    }
}

public enum SlotFill: Hashable, Sendable {
    case recipe(String)
    /// One of the owner's packaged products (yogurt, bar…), eaten as a snack.
    case product(String)
    /// Food from family, a café… Nothing to buy or cook.
    case outside
}

/// A packaged product from "My products" as the planner sees it.
public struct PlanProduct: Hashable, Sendable {
    public var id: String
    public var name: String
    /// One portion: the whole pack, or 100 g when it is not sold in packs.
    public var portion: Nutrition
    /// Price of one portion; nil when the owner did not enter one.
    public var priceUAH: Double?

    public init(id: String, name: String, portion: Nutrition, priceUAH: Double? = nil) {
        self.id = id
        self.name = name
        self.portion = portion
        self.priceUAH = priceUAH
    }
}

/// How many portions of a product the plan eats, and what they cost if the price is known.
public struct ProductPurchase: Hashable, Sendable {
    public var product: PlanProduct
    public var count: Int
    public var costUAH: Double?
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
    /// Packaged snacks from "My products".
    public var products: [ProductPurchase] = []

    public var totalUAH: Double {
        list.totalUAH + products.compactMap(\.costUAH).reduce(0, +)
    }
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
        /// Most snacks a day gets: the first one always, the next ones only while the day is
        /// clearly below the calorie target (T-019). 0 plans no snacks.
        public var snacksPerDay: Int
        /// "My products" that may be planned as snacks.
        public var products: [PlanProduct]

        public init(
            days: Int,
            meals: [MealType] = MealPlanner.defaultMeals,
            fixed: [PlanSlot: SlotFill] = [:],
            available: Set<String> = [],
            prices: [String: Double] = [:],
            dailyTarget: Nutrition? = nil,
            defaultStorageDays: Int = 3,
            snacksPerDay: Int = 0,
            products: [PlanProduct] = []
        ) {
            self.days = days
            self.meals = meals
            self.fixed = fixed
            self.available = available
            self.prices = prices
            self.dailyTarget = dailyTarget
            self.defaultStorageDays = defaultStorageDays
            self.snacksPerDay = snacksPerDay
            self.products = products
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
            // Occasional dishes only get into a plan by hand.
            let candidates = catalog.recipes.filter { !$0.isOccasional && MealSuggester.fits($0, meal: slot.meal) }
            let best = candidates.max { a, b in
                let sa = score(a, slot: slot, fills: fills, request: request, catalog: catalog)
                let sb = score(b, slot: slot, fills: fills, request: request, catalog: catalog)
                return (sa, b.id) < (sb, a.id)
            }
            if let best { fills[slot] = .recipe(best.id) }
        }
        fillSnacks(&fills, request: request, catalog: catalog)
        return fills
    }

    /// A day still this many kcal short of the target after the first snack gets another one.
    public static let secondSnackGap: Double = 300

    private static func fillSnacks(_ fills: inout [PlanSlot: SlotFill], request: Request, catalog: Catalog) {
        guard request.snacksPerDay > 0 else { return }
        for day in 0..<request.days {
            for number in 0..<request.snacksPerDay {
                let slot = PlanSlot(day: day, meal: .snack, number: number)
                if fills[slot] != nil { continue }
                let gap = request.dailyTarget.map {
                    $0.kcal - nutrition(day: day, fills: fills, catalog: catalog, products: request.products).kcal
                }
                if number > 0 {
                    guard let gap, gap > secondSnackGap else { break }
                }
                if let best = bestSnack(slot: slot, gap: gap, fills: fills, request: request, catalog: catalog) {
                    fills[slot] = best
                }
            }
        }
    }

    /// The snack recipe or product whose calories best close the day's gap, preferring some
    /// protein, what is already at home or on the list, low cost and variety.
    private static func bestSnack(slot: PlanSlot, gap: Double?, fills: [PlanSlot: SlotFill], request: Request, catalog: Catalog) -> SlotFill? {
        func snackScore(_ fill: SlotFill, _ n: Nutrition, coverage: Double, cost: Double) -> Double {
            var score = 0.0
            if let gap { score -= abs(gap - n.kcal) / 300 }
            score += min(n.protein / 20, 1)
            score += coverage
            score -= cost / 150
            score -= Double(fills.values.filter { $0 == fill }.count) * 1.5
            if fills.contains(where: { $0.key.day == slot.day && $0.value == fill }) { score -= 3 }
            return score
        }
        var options: [(fill: SlotFill, key: String, score: Double)] = []
        for recipe in catalog.recipes where !recipe.isOccasional && recipe.mealTypes.contains(.snack) {
            let fill = SlotFill.recipe(recipe.id)
            let (coverage, cost) = reuse(recipe, fills: fills, request: request, catalog: catalog)
            options.append((fill, "r-" + recipe.id, snackScore(fill, catalog.nutritionPerServing(of: recipe), coverage: coverage, cost: cost)))
        }
        for product in request.products {
            let fill = SlotFill.product(product.id)
            // Nothing is known about products at home, so they count as half covered.
            options.append((fill, "p-" + product.id, snackScore(fill, product.portion, coverage: 0.5, cost: product.priceUAH ?? 0)))
        }
        return options.max { ($0.score, $1.key) < ($1.score, $0.key) }?.fill
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
    public static func nutrition(day: Int, fills: [PlanSlot: SlotFill], catalog: Catalog, products: [PlanProduct] = []) -> Nutrition {
        fills.filter { $0.key.day == day }.reduce(.zero) { sum, entry in
            switch entry.value {
            case .recipe(let id):
                guard let recipe = catalog.recipes.first(where: { $0.id == id }) else { return sum }
                return sum + catalog.nutritionPerServing(of: recipe)
            case .product(let id):
                guard let product = products.first(where: { $0.id == id }) else { return sum }
                return sum + product.portion
            case .outside:
                return sum
            }
        }
    }

    /// Portions of "My products" the plan eats, most first.
    public static func productPurchases(for fills: [PlanSlot: SlotFill], products: [PlanProduct]) -> [ProductPurchase] {
        var counts: [String: Int] = [:]
        for fill in fills.values {
            if case .product(let id) = fill { counts[id, default: 0] += 1 }
        }
        return products.compactMap { product in
            counts[product.id].map { ProductPurchase(product: product, count: $0, costUAH: product.priceUAH.map { $0 * Double(counts[product.id]!) }) }
        }
        .sorted { ($1.count, $0.product.name) < ($0.count, $1.product.name) }
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

    /// Share of the recipe's ingredients already at home or on the list, and what the rest costs.
    private static func reuse(_ recipe: Recipe, fills: [PlanSlot: SlotFill], request: Request, catalog: Catalog) -> (coverage: Double, extraCost: Double) {
        let onList = Set(fills.values.compactMap { fill -> String? in
            if case .recipe(let id) = fill { id } else { nil }
        }.compactMap { id in catalog.recipes.first { $0.id == id } }.flatMap { $0.ingredients.map(\.ingredientID) })

        let required = recipe.ingredients.filter { !$0.optional }
        let covered = required.filter { request.available.contains($0.ingredientID) || onList.contains($0.ingredientID) }
        let extraCost = required.filter { !request.available.contains($0.ingredientID) && !onList.contains($0.ingredientID) }
            .compactMap { catalog.ingredient($0.ingredientID) }
            .reduce(0) { $0 + (request.prices[$1.id] ?? $1.packPriceUAH) }
        return (required.isEmpty ? 1 : Double(covered.count) / Double(required.count), extraCost)
    }

    private static func score(_ recipe: Recipe, slot: PlanSlot, fills: [PlanSlot: SlotFill], request: Request, catalog: Catalog) -> Double {
        let used = fills.values.filter { $0 == .recipe(recipe.id) }.count
        let (coverage, extraCost) = reuse(recipe, fills: fills, request: request, catalog: catalog)

        let protein = catalog.nutritionPerServing(of: recipe).protein
        let proteinPerMeal = (request.dailyTarget?.protein ?? 126) / Double(max(request.meals.count, 1))

        var score = min(protein / proteinPerMeal, 1.2) * 2
        score += coverage
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
