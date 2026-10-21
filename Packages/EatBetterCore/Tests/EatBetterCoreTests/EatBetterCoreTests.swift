import Foundation
import Testing
@testable import EatBetterCore

private func bundledCatalog() throws -> Catalog {
    try Catalog(ingredients: Catalog.bundledIngredients(), recipes: Catalog.demoRecipes())
}

@Suite struct CatalogTests {
    @Test func bundledDataLoadsAndIsConsistent() throws {
        let catalog = try bundledCatalog()
        #expect(catalog.ingredients.count >= 10)
        #expect(catalog.recipes.count >= 5)
        #expect(Set(catalog.recipes.map(\.id)).count == catalog.recipes.count)
        for recipe in catalog.recipes {
            #expect(!recipe.steps.isEmpty)
            #expect(recipe.servings >= 1)
        }
    }

    @Test func unknownIngredientIsRejected() throws {
        let recipe = Recipe(
            id: "r", name: .init(en: "R", uk: "R"), mealTypes: [.lunch], servings: 1, totalMinutes: 5,
            ingredients: [RecipeIngredient(ingredientID: "nope", grams: 10)], steps: []
        )
        #expect(throws: CatalogError.unknownIngredient(recipeID: "r", ingredientID: "nope")) {
            try Catalog(ingredients: [], recipes: [recipe])
        }
    }
}

@Suite struct DailyTargetsTests {
    // Example profile used in docs: 70 kg, 180 cm, 25 y, male, moderate activity, gaining.
    let profile = BodyProfile(weightKg: 70, heightCm: 180, ageYears: 25, sex: .male, activity: .moderate, goal: .gain)

    @Test func bmrMatchesMifflinStJeor() {
        #expect(DailyTargets.bmr(for: profile) == 1705)
    }

    @Test func targetsForGain() {
        let t = DailyTargets.targets(for: profile)
        #expect(abs(t.kcal - 3042.75) < 0.01)
        #expect(t.protein == 126)
        #expect(t.fat == 70)
        #expect(abs(t.carbs - (3042.75 - 126 * 4 - 70 * 9) / 4) < 0.01)
    }

    @Test func maintainHasNoSurplus() {
        var p = profile
        p.goal = .maintain
        #expect(abs(DailyTargets.targets(for: p).kcal - 1705 * 1.55) < 0.01)
    }
}

@Suite struct RecipeMathTests {
    @Test func perServingNutritionSumsIngredients() throws {
        let catalog = try bundledCatalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "demo_cottage_banana" })
        let n = catalog.nutritionPerServing(of: recipe)
        // 200 g cottage cheese + 120 g banana
        #expect(abs(n.kcal - (121 * 2 + 89 * 1.2)) < 0.001)
        #expect(abs(n.protein - (17 * 2 + 1.1 * 1.2)) < 0.001)
    }

    @Test func servingsDivideTotal() throws {
        let catalog = try bundledCatalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "demo_chicken_buckwheat" })
        let total = catalog.totalNutrition(of: recipe)
        let one = catalog.nutritionPerServing(of: recipe)
        #expect(abs(one.kcal * 3 - total.kcal) < 0.001)
    }

    @Test func scalingMultipliesAmountsAndServings() throws {
        let catalog = try bundledCatalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "demo_pasta_tuna" })
        let tripled = recipe.scaled(by: 3)
        #expect(tripled.servings == 6)
        #expect(tripled.ingredients.first?.grams == 600)
        #expect(abs(catalog.totalNutrition(of: tripled).kcal - catalog.totalNutrition(of: recipe).kcal * 3) < 0.001)
    }

    @Test func householdAmountUsesUnits() throws {
        let catalog = try bundledCatalog()
        let eggs = try #require(catalog.householdAmount(ingredientID: "egg", grams: 150))
        #expect(eggs.count == 3)
        let oil = try #require(catalog.householdAmount(ingredientID: "sunflower_oil", grams: 26))
        #expect(oil.unit.name.en == "tbsp")
        #expect(oil.count == 2)
        #expect(catalog.householdAmount(ingredientID: "chicken_breast", grams: 600) == nil)
    }
}

@Suite struct PantryMatcherTests {
    @Test func allRequiredIngredientsMeansCanCook() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: ["cottage_cheese", "banana"])
        #expect(result.canCookNow.map(\.recipe.id).contains("demo_cottage_banana"))
    }

    @Test func optionalIngredientsDoNotBlock() throws {
        let catalog = try bundledCatalog()
        // Oatmeal needs oats, milk, banana; salt is optional.
        let result = PantryMatcher.match(catalog: catalog, available: ["oats", "milk", "banana"])
        #expect(result.canCookNow.map(\.recipe.id).contains("demo_oatmeal_banana"))
    }

    @Test func oneMissingIngredientIsReportedWithPrice() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: ["cottage_cheese"], prices: ["banana": 80])
        let match = try #require(result.almost.first { $0.recipe.id == "demo_cottage_banana" })
        #expect(match.missing.map(\.id) == ["banana"])
        #expect(match.missingCostUAH == 80)
    }

    @Test func tooManyMissingIsExcluded() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: [])
        #expect(!result.almost.contains { $0.recipe.id == "demo_chicken_buckwheat" })
        #expect(result.canCookNow.isEmpty)
    }

    @Test func almostIsSortedByMissingCount() throws {
        let catalog = try bundledCatalog()
        let result = PantryMatcher.match(catalog: catalog, available: ["banana", "milk"])
        let counts = result.almost.map(\.missing.count)
        #expect(counts == counts.sorted())
    }
}

@Suite struct ShoppingPlannerTests {
    @Test func aggregatesAcrossRecipesAndSkipsAvailable() throws {
        let catalog = try bundledCatalog()
        let chicken = try #require(catalog.recipes.first { $0.id == "demo_chicken_buckwheat" })
        let rice = try #require(catalog.recipes.first { $0.id == "demo_rice_chicken_veg" })
        let list = ShoppingPlanner.list(
            for: [PlannedBatch(recipe: chicken), PlannedBatch(recipe: rice)],
            catalog: catalog,
            available: ["sunflower_oil"]
        )
        let ids = list.items.map(\.ingredient.id)
        #expect(!ids.contains("sunflower_oil"))
        #expect(!ids.contains("salt")) // optional
        let chickenItem = try #require(list.items.first { $0.ingredient.id == "chicken_breast" })
        #expect(chickenItem.gramsNeeded == 1050)
        #expect(chickenItem.packs == 2)
        #expect(chickenItem.costUAH == 500)
        #expect(list.totalUAH == list.items.reduce(0) { $0 + $1.costUAH })
    }

    @Test func scaleMultipliesNeededGrams() throws {
        let catalog = try bundledCatalog()
        let pasta = try #require(catalog.recipes.first { $0.id == "demo_pasta_tuna" })
        let list = ShoppingPlanner.list(for: [PlannedBatch(recipe: pasta, scale: 3)], catalog: catalog, available: [])
        let item = try #require(list.items.first { $0.ingredient.id == "pasta" })
        #expect(item.gramsNeeded == 600)
        #expect(item.packs == 2)
    }
}

@Suite struct FoodTests {
    @Test func dishesLoadWithPortions() throws {
        let dishes = try Catalog.bundledDishes()
        #expect(dishes.count >= 20)
        #expect(Set(dishes.map(\.id)).count == dishes.count)
        for dish in dishes {
            #expect(!dish.units.isEmpty)
            #expect(dish.per100g.kcal > 0)
        }
    }

    @Test func nutritionScalesWithGrams() {
        let food = Food(id: "f", name: .init(en: "F", uk: "F"), per100g: Nutrition(kcal: 200, protein: 10, fat: 5, carbs: 20),
                        units: [HouseholdUnit(name: .init(en: "bowl", uk: "тарілка"), grams: 300)])
        #expect(food.nutrition(grams: 150) == Nutrition(kcal: 300, protein: 15, fat: 7.5, carbs: 30))
        #expect(food.grams(of: .medium) == 300)
        #expect(food.grams(of: .small) == 210)
        #expect(food.grams(of: .large) == 420)
    }

    @Test func ingredientBecomesFood() throws {
        let catalog = try bundledCatalog()
        let banana = Food(try #require(catalog.ingredient("banana")))
        #expect(banana.per100g.kcal == 89)
        #expect(banana.grams(of: .medium) == banana.units.first?.grams)
    }
}

@Suite struct ClaudeFoodCodeTests {
    @Test func parsesCodeInsideText() {
        let text = """
        Ось оцінка:
        `EB1|Котлети з пюре|650|35|30|55`
        """
        let codes = ClaudeFoodCode.parseAll(text)
        #expect(codes == [ClaudeFoodCode(title: "Котлети з пюре", perServing: Nutrition(kcal: 650, protein: 35, fat: 30, carbs: 55))])
    }

    @Test func acceptsDecimalCommaAndServings() throws {
        let code = try #require(ClaudeFoodCode.parseAll("EB1|Плов|540,5|22,5|18|70|3").first)
        #expect(code.perServing.kcal == 540.5)
        #expect(code.perServing.protein == 22.5)
        #expect(code.servings == 3)
    }

    @Test func readsSeveralLinesAndSkipsBadOnes() {
        let codes = ClaudeFoodCode.parseAll("EB1|A|100|1|1|1\nEB1|B|lots|1|1|1\nEB1||1|1|1|1\nEB1|C|200|2|2|2")
        #expect(codes.map(\.title) == ["A", "C"])
    }

    @Test func rejectsMissingFields() {
        #expect(ClaudeFoodCode.parseAll("EB1|Soup|100|2|3").isEmpty)
        #expect(ClaudeFoodCode.parseAll("no code here").isEmpty)
    }
}

@Suite struct MealSuggesterTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func date(hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: hour))!
    }

    func context(hour: Int, available: Set<String>, ready: [ReadyItem] = [], recent: Set<String> = []) throws -> (MealSuggester.Context, Catalog) {
        let catalog = try bundledCatalog()
        let ctx = MealSuggester.Context(
            now: date(hour: hour), calendar: calendar, ready: ready,
            pantry: PantryMatcher.match(catalog: catalog, available: available),
            eaten: .zero, target: Nutrition(kcal: 3000, protein: 126, fat: 70, carbs: 400),
            recentRecipeIDs: recent
        )
        return (ctx, catalog)
    }

    @Test func mealFollowsTimeOfDay() {
        #expect(MealType.at(hour: 8) == .breakfast)
        #expect(MealType.at(hour: 13) == .lunch)
        #expect(MealType.at(hour: 19) == .dinner)
        #expect(MealType.at(hour: 23) == .snack)
    }

    @Test func morningSuggestsBreakfastNotDinner() throws {
        // Everything in the fridge: both breakfast and lunch/dinner recipes are cookable.
        let all = Set(try bundledCatalog().ingredients.keys)
        let (ctx, catalog) = try context(hour: 8, available: all)
        let ids = MealSuggester.suggestions(ctx, catalog: catalog).compactMap { s -> String? in
            if case .cookNow(let id) = s.kind { return id } else { return nil }
        }
        #expect(!ids.isEmpty)
        #expect(!ids.contains("demo_chicken_buckwheat"))
        #expect(ids.contains("demo_oatmeal_banana"))
    }

    @Test func readyPortionComesFirstAndExpiringIsFlagged() throws {
        let all = Set(try bundledCatalog().ingredients.keys)
        let soup = ReadyItem(id: "p1", title: "Soup", nutrition: Nutrition(kcal: 400, protein: 25, fat: 10, carbs: 40),
                             expiresAt: date(hour: 8).addingTimeInterval(20 * 3600))
        let (ctx, catalog) = try context(hour: 8, available: all, ready: [soup])
        let first = try #require(MealSuggester.suggestions(ctx, catalog: catalog).first)
        #expect(first.kind == .ready(id: "p1"))
        #expect(first.reasons.contains(.eatSoon))
    }

    @Test func oneMissingIngredientIsOfferedAsBuyFirst() throws {
        let (ctx, catalog) = try context(hour: 8, available: ["cottage_cheese"])
        let suggestions = MealSuggester.suggestions(ctx, catalog: catalog)
        let buy = try #require(suggestions.first { if case .buyFirst(let id, _) = $0.kind { id == "demo_cottage_banana" } else { false } })
        if case .buyFirst(_, let missing) = buy.kind { #expect(missing.map(\.id) == ["banana"]) }
    }

    @Test func recentlyEatenDropsLower() throws {
        let all = Set(try bundledCatalog().ingredients.keys)
        let (fresh, catalog) = try context(hour: 13, available: all)
        let (repeated, _) = try context(hour: 13, available: all, recent: ["demo_rice_chicken_veg"])
        func score(_ ctx: MealSuggester.Context) -> Double {
            MealSuggester.suggestions(ctx, catalog: catalog).first { $0.kind == .cookNow(recipeID: "demo_rice_chicken_veg") }!.score
        }
        #expect(score(repeated) < score(fresh))
    }

    @Test func emptyFridgeAndNothingReadyGivesNothing() throws {
        let (ctx, catalog) = try context(hour: 13, available: [])
        #expect(MealSuggester.suggestions(ctx, catalog: catalog).isEmpty)
    }
}

@Suite struct MealPlannerTests {
    var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func day(_ d: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: d))! // 2026-03-10 is a Tuesday
    }

    @Test func periodRunsToTheNextShoppingDay() {
        let saturdayAndWednesday: Set<Int> = [7, 4]
        let fromTuesday = ShoppingSchedule.period(from: day(10), weekdays: saturdayAndWednesday, calendar: calendar)
        #expect(fromTuesday.start == day(11))
        #expect(fromTuesday.days == 3)
        let fromSaturday = ShoppingSchedule.period(from: day(14), weekdays: saturdayAndWednesday, calendar: calendar)
        #expect(fromSaturday.start == day(14))
        #expect(fromSaturday.days == 4)
        let weekly = ShoppingSchedule.period(from: day(14), weekdays: [7], calendar: calendar)
        #expect(weekly.days == 7)
        #expect(ShoppingSchedule.period(from: day(10), weekdays: [], calendar: calendar).days == 3)
    }

    @Test func fillCoversEverySlotAndCooksAhead() throws {
        let catalog = try bundledCatalog()
        let request = MealPlanner.Request(days: 3, dailyTarget: Nutrition(kcal: 3000, protein: 126, fat: 70, carbs: 400))
        let fills = MealPlanner.fill(request, catalog: catalog)
        #expect(fills.count == 9)
        for d in 0..<3 {
            let dishes = fills.filter { $0.key.day == d }.map(\.value)
            #expect(Set(dishes).count == dishes.count, "same dish twice on day \(d)")
        }
        let batches = MealPlanner.batches(for: fills, catalog: catalog)
        // Lunches and dinners come from 3-serving recipes, so far fewer cookings than slots.
        let mainBatches = batches.filter { $0.cookSlot.meal == .lunch || $0.cookSlot.meal == .dinner }
        #expect(mainBatches.count <= 3)
        #expect(mainBatches.allSatisfy { $0.slots.count <= $0.recipe.servings })
    }

    @Test func occasionalDishesAreNeverPickedAutomatically() throws {
        let base = try bundledCatalog()
        // Mark every lunch/dinner dish but one as occasional: the plan must use only that one.
        let recipes = base.recipes.map { recipe -> Recipe in
            var copy = recipe
            copy.occasional = recipe.mealTypes.contains(.lunch) && recipe.id != "demo_pasta_tuna"
            return copy
        }
        let catalog = try Catalog(ingredients: Array(base.ingredients.values), recipes: recipes)
        let fills = MealPlanner.fill(MealPlanner.Request(days: 2, meals: [.lunch, .dinner]), catalog: catalog)
        #expect(Set(fills.values) == [.recipe("demo_pasta_tuna")])
        // By hand it is fine.
        let manual = MealPlanner.fill(
            MealPlanner.Request(days: 1, meals: [.lunch], fixed: [PlanSlot(day: 0, meal: .lunch): .recipe("demo_chicken_buckwheat")]),
            catalog: catalog
        )
        #expect(manual[PlanSlot(day: 0, meal: .lunch)] == .recipe("demo_chicken_buckwheat"))
    }

    @Test func fixedSlotsAreKept() throws {
        let catalog = try bundledCatalog()
        let outside = PlanSlot(day: 0, meal: .dinner)
        let chosen = PlanSlot(day: 1, meal: .breakfast)
        let fills = MealPlanner.fill(
            MealPlanner.Request(days: 2, fixed: [outside: .outside, chosen: .recipe("demo_cottage_banana")]),
            catalog: catalog
        )
        #expect(fills[outside] == .outside)
        #expect(fills[chosen] == .recipe("demo_cottage_banana"))
        #expect(fills.count == 6)
    }

    @Test func batchesRespectServingsAndStorage() throws {
        let catalog = try bundledCatalog()
        let id = "demo_chicken_buckwheat" // 3 servings, keeps 4 days
        let fills: [PlanSlot: SlotFill] = [
            PlanSlot(day: 0, meal: .lunch): .recipe(id),
            PlanSlot(day: 1, meal: .lunch): .recipe(id),
            PlanSlot(day: 4, meal: .lunch): .recipe(id), // too late for the first batch
        ]
        let batches = MealPlanner.batches(for: fills, catalog: catalog)
        #expect(batches.map(\.slots.count) == [2, 1])
        #expect(batches.last?.cookSlot == PlanSlot(day: 4, meal: .lunch))
    }

    @Test func shoppingSkipsWhatIsHomeButListsItToCheck() throws {
        let catalog = try bundledCatalog()
        let fills: [PlanSlot: SlotFill] = [PlanSlot(day: 0, meal: .lunch): .recipe("demo_chicken_buckwheat"), PlanSlot(day: 0, meal: .dinner): .outside]
        let plan = MealPlanner.shopping(for: MealPlanner.batches(for: fills, catalog: catalog), catalog: catalog, available: ["buckwheat"])
        #expect(!plan.list.items.contains { $0.ingredient.id == "buckwheat" })
        #expect(plan.list.items.contains { $0.ingredient.id == "chicken_breast" })
        #expect(plan.checkAtHome.map(\.ingredient.id) == ["buckwheat"])
    }

    @Test func dayNutritionSumsPlannedServings() throws {
        let catalog = try bundledCatalog()
        let recipe = try #require(catalog.recipes.first { $0.id == "demo_oatmeal_banana" })
        let fills: [PlanSlot: SlotFill] = [PlanSlot(day: 0, meal: .breakfast): .recipe(recipe.id), PlanSlot(day: 0, meal: .lunch): .outside]
        #expect(MealPlanner.nutrition(day: 0, fills: fills, catalog: catalog) == catalog.nutritionPerServing(of: recipe))
    }
}

@Suite struct SnackPlanTests {
    let yogurt = PlanProduct(id: "my-1", name: "Yogurt", portion: Nutrition(kcal: 250, protein: 10, fat: 8, carbs: 30), priceUAH: 45)
    let target = Nutrition(kcal: 2900, protein: 126, fat: 70, carbs: 400)

    func snacks(_ fills: [PlanSlot: SlotFill], day: Int) -> [SlotFill] {
        fills.filter { $0.key.day == day && $0.key.meal == .snack }.sorted { $0.key < $1.key }.map(\.value)
    }

    @Test func everyDayGetsOneOrTwoSnacksAndGetsCloserToTarget() throws {
        let catalog = try bundledCatalog()
        let snackIDs = Set(catalog.recipes.filter { $0.mealTypes.contains(.snack) }.map(\.id))
        let without = MealPlanner.fill(MealPlanner.Request(days: 3, dailyTarget: target), catalog: catalog)
        let request = MealPlanner.Request(days: 3, dailyTarget: target, snacksPerDay: 2, products: [yogurt])
        let fills = MealPlanner.fill(request, catalog: catalog)
        for d in 0..<3 {
            let daySnacks = snacks(fills, day: d)
            #expect((1...2).contains(daySnacks.count), "day \(d)")
            for snack in daySnacks {
                switch snack {
                case .recipe(let id): #expect(snackIDs.contains(id))
                case .product(let id): #expect(id == yogurt.id)
                case .outside: Issue.record("outside is never planned automatically")
                }
            }
            let before = MealPlanner.nutrition(day: d, fills: without, catalog: catalog).kcal
            let after = MealPlanner.nutrition(day: d, fills: fills, catalog: catalog, products: [yogurt]).kcal
            #expect(abs(target.kcal - after) < abs(target.kcal - before))
        }
    }

    @Test func secondSnackOnlyWhenTheDayIsShort() throws {
        let catalog = try bundledCatalog()
        // A tiny target is met by the meals: still one snack, never a second one.
        let small = MealPlanner.fill(
            MealPlanner.Request(days: 2, dailyTarget: Nutrition(kcal: 800, protein: 50, fat: 30, carbs: 80), snacksPerDay: 2),
            catalog: catalog
        )
        #expect(snacks(small, day: 0).count == 1)
        #expect(snacks(small, day: 1).count == 1)
        // No target known: one snack.
        let unknown = MealPlanner.fill(MealPlanner.Request(days: 1, snacksPerDay: 2), catalog: catalog)
        #expect(snacks(unknown, day: 0).count == 1)
    }

    @Test func occasionalAndBreakfastOnlyDishesAreNotSnacks() throws {
        let base = try bundledCatalog()
        let recipes = base.recipes.map { recipe -> Recipe in
            var copy = recipe
            copy.occasional = recipe.id == "demo_cottage_banana"
            return copy
        }
        let catalog = try Catalog(ingredients: Array(base.ingredients.values), recipes: recipes)
        let fills = MealPlanner.fill(MealPlanner.Request(days: 3, dailyTarget: target, snacksPerDay: 2), catalog: catalog)
        let used = Set(fills.filter { $0.key.meal == .snack }.map(\.value))
        #expect(!used.contains(.recipe("demo_cottage_banana")))
        #expect(!used.contains(.recipe("demo_oatmeal_banana")))
    }

    @Test func fixedSnackIsKeptAndProductsAreBought() throws {
        let catalog = try bundledCatalog()
        let slot = PlanSlot(day: 0, meal: .snack)
        let fills = MealPlanner.fill(
            MealPlanner.Request(days: 2, fixed: [slot: .product(yogurt.id)], dailyTarget: target, snacksPerDay: 1, products: [yogurt]),
            catalog: catalog
        )
        #expect(fills[slot] == .product(yogurt.id))
        let purchases = MealPlanner.productPurchases(for: fills, products: [yogurt])
        let count = fills.values.filter { $0 == .product(yogurt.id) }.count
        #expect(purchases.first?.count == count)
        #expect(purchases.first?.costUAH == Double(count) * 45)
    }

    @Test func secondSnackComesAfterDinner() {
        #expect(PlanSlot(day: 0, meal: .snack) < PlanSlot(day: 0, meal: .dinner))
        #expect(PlanSlot(day: 0, meal: .dinner) < PlanSlot(day: 0, meal: .snack, number: 1))
        #expect(PlanSlot(day: 0, meal: .snack, number: 1) < PlanSlot(day: 1, meal: .breakfast))
    }
}

@Suite struct PackPriceTests {
    @Test func packAndPriceReplaceTheCatalogOnes() throws {
        let catalog = try bundledCatalog().applying([
            PackPrice(ingredientID: "buckwheat", packGrams: 800, packPriceUAH: 58),
            PackPrice(ingredientID: "egg", packPriceUAH: 70),
            PackPrice(ingredientID: "unknown", packPriceUAH: 10),
            PackPrice(ingredientID: "rice_white", packPriceUAH: 0),
        ])
        let original = try bundledCatalog()
        #expect(catalog.ingredient("buckwheat")?.packGrams == 800)
        #expect(catalog.ingredient("buckwheat")?.packPriceUAH == 58)
        #expect(catalog.ingredient("egg")?.packGrams == original.ingredient("egg")?.packGrams)
        #expect(catalog.ingredient("egg")?.packPriceUAH == 70)
        #expect(catalog.ingredient("rice_white") == original.ingredient("rice_white"))
        #expect(catalog.ingredient("unknown") == nil)
        // 1000 g of buckwheat in 800 g packs: 2 packs.
        let recipe = Recipe(id: "r", name: .init(en: "R", uk: "R"), mealTypes: [.lunch], servings: 1, totalMinutes: 5,
                            ingredients: [RecipeIngredient(ingredientID: "buckwheat", grams: 1000)], steps: [])
        let list = ShoppingPlanner.list(for: [PlannedBatch(recipe: recipe)], catalog: catalog, available: [])
        #expect(list.items.first?.packs == 2)
        #expect(list.totalUAH == 116)
    }

    @Test func privatePriceFileDecodes() throws {
        let json = #"[{"ingredient": "egg", "packGrams": 600, "packPriceUAH": 72.5, "note": "10 eggs"}, {"ingredient": "milk", "packPriceUAH": 50}]"#
        let packs = try JSONDecoder().decode([PackPrice].self, from: Data(json.utf8))
        #expect(packs == [PackPrice(ingredientID: "egg", packGrams: 600, packPriceUAH: 72.5), PackPrice(ingredientID: "milk", packPriceUAH: 50)])
    }
}

@Suite struct BackupTests {
    let date = Date(timeIntervalSinceReferenceDate: 800_000_000.123456)

    var sample: Backup {
        Backup(
            exportedAt: date,
            profile: .init(weightKg: 70, heightCm: 180, ageYears: 25, sex: "male", activity: "moderate", goal: "gain", defaultStorageDays: 7),
            settings: .init(shoppingWeekdays: "4,7", language: "uk"),
            fridge: ["egg", "milk"],
            prices: [.init(ingredientID: "egg", packPriceUAH: 70, packGrams: 600)],
            products: [.init(id: "my-1", name: "Yogurt", per100g: Nutrition(kcal: 90, protein: 5, fat: 3, carbs: 10), packGrams: 300, packPriceUAH: 45, createdAt: date)],
            readyPortions: [.init(recipeID: "r", title: "Dish", nutrition: .zero, cookedAt: date, expiresAt: date.addingTimeInterval(86_400))],
            log: [.init(date: date, title: "Toast", recipeID: nil, nutrition: Nutrition(kcal: 300, protein: 10, fat: 10, carbs: 40))],
            plan: [.init(day: date, meal: "snack", number: 1, recipeID: nil, productID: "my-1", isOutside: false, isManual: true, cookedAt: nil)],
            bought: ["milk"]
        )
    }

    @Test func roundTripIsExact() throws {
        let decoded = try Backup.decode(sample.encoded())
        #expect(decoded == sample)
    }

    @Test func missingSectionsAreEmpty() throws {
        let decoded = try Backup.decode(Data(#"{"version": 1, "fridge": ["egg"]}"#.utf8))
        #expect(decoded.fridge == ["egg"])
        #expect(decoded.profile == nil)
        #expect(decoded.log.isEmpty && decoded.readyPortions.isEmpty && decoded.products.isEmpty)
    }

    @Test func newerFilesAreRefused() {
        #expect(throws: Backup.FileError.newerVersion(99)) {
            try Backup.decode(Data(#"{"version": 99}"#.utf8))
        }
    }

    @Test func addingKeepsTheDeviceAndNeverDoubles() {
        var device = Backup(
            profile: .init(weightKg: 60, heightCm: 170, ageYears: 30, sex: "female", activity: "light", goal: "maintain", defaultStorageDays: 5),
            fridge: ["bread", "egg"],
            prices: [.init(ingredientID: "egg", packPriceUAH: 99)]
        )
        device.log = [.init(date: date.addingTimeInterval(60), title: "Apple", recipeID: nil, nutrition: .zero)]
        let once = device.adding(sample)
        #expect(once.profile == device.profile)
        #expect(once.settings == sample.settings)
        #expect(once.fridge == ["bread", "egg", "milk"])
        #expect(once.prices == device.prices)
        #expect(once.products == sample.products)
        #expect(once.log.count == 2)
        #expect(once.readyPortions.count == 1)
        #expect(once.plan.count == 1)
        #expect(once.adding(sample) == once)
    }
}
