import EatBetterCore
import Foundation
import SwiftData

/// Personal data. Lives only in the on-device SwiftData store (and in user-made backups).

@Model
final class ProfileRecord {
    var weightKg: Double
    var heightCm: Double
    var ageYears: Int
    var sexRaw: String
    var activityRaw: String
    var goalRaw: String
    /// Days a cooked portion keeps when the recipe does not say otherwise.
    var defaultStorageDays: Int

    init(
        weightKg: Double = 70,
        heightCm: Double = 175,
        ageYears: Int = 25,
        sex: Sex = .male,
        activity: ActivityLevel = .moderate,
        goal: Goal = .gain,
        defaultStorageDays: Int = 7
    ) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.ageYears = ageYears
        self.sexRaw = sex.rawValue
        self.activityRaw = activity.rawValue
        self.goalRaw = goal.rawValue
        self.defaultStorageDays = defaultStorageDays
    }

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }

    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }

    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .gain }
        set { goalRaw = newValue.rawValue }
    }

    var bodyProfile: BodyProfile {
        BodyProfile(weightKg: weightKg, heightCm: heightCm, ageYears: ageYears, sex: sex, activity: activity, goal: goal)
    }
}

/// Presence means "I have this ingredient". Only changed by the user, never automatically.
@Model
final class PantryItem {
    @Attribute(.unique) var ingredientID: String

    init(ingredientID: String) {
        self.ingredientID = ingredientID
    }
}

/// Per-device pack price that replaces the catalog estimate (T-011).
@Model
final class PriceOverride {
    @Attribute(.unique) var ingredientID: String
    var packPriceUAH: Double
    /// Pack size the price is for; 0 keeps the catalog pack.
    var packGrams: Double = 0

    init(ingredientID: String, packPriceUAH: Double, packGrams: Double = 0) {
        self.ingredientID = ingredientID
        self.packPriceUAH = packPriceUAH
        self.packGrams = packGrams
    }

    var packPrice: PackPrice {
        PackPrice(ingredientID: ingredientID, packGrams: packGrams, packPriceUAH: packPriceUAH)
    }
}

@Model
final class MealLogEntry {
    var date: Date
    var title: String
    var recipeID: String?
    var kcal: Double
    var protein: Double
    var fat: Double
    var carbs: Double

    init(date: Date = .now, title: String, recipeID: String? = nil, nutrition: Nutrition) {
        self.date = date
        self.title = title
        self.recipeID = recipeID
        self.kcal = nutrition.kcal
        self.protein = nutrition.protein
        self.fat = nutrition.fat
        self.carbs = nutrition.carbs
    }

    var nutrition: Nutrition {
        Nutrition(kcal: kcal, protein: protein, fat: fat, carbs: carbs)
    }
}

/// One portion waiting in the fridge: home-cooked or brought from outside (D-016).
/// Title and nutrition are stored, so outside food needs no recipe.
@Model
final class ReadyPortion {
    var recipeID: String?
    var title: String = ""
    var kcal: Double = 0
    var protein: Double = 0
    var fat: Double = 0
    var carbs: Double = 0
    var cookedAt: Date
    var expiresAt: Date

    init(title: String, recipeID: String? = nil, nutrition: Nutrition, cookedAt: Date = .now, expiresAt: Date) {
        self.title = title
        self.recipeID = recipeID
        self.kcal = nutrition.kcal
        self.protein = nutrition.protein
        self.fat = nutrition.fat
        self.carbs = nutrition.carbs
        self.cookedAt = cookedAt
        self.expiresAt = expiresAt
    }

    var nutrition: Nutrition {
        Nutrition(kcal: kcal, protein: protein, fat: fat, carbs: carbs)
    }
}

/// A packaged food or snack entered once from its label, then logged in one tap (D-016).
@Model
final class MyProduct {
    var name: String
    var kcal: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    /// Pack weight in grams; 0 when the product is not sold in packs.
    var packGrams: Double
    var createdAt: Date
    /// Price of one pack (of 100 g when there is no pack), for the plan's shopping list.
    var packPriceUAH: Double?
    /// Set when the product came from a backup; older products use their creation time.
    var productID: String?

    init(name: String, per100g: Nutrition, packGrams: Double, packPriceUAH: Double? = nil, createdAt: Date = .now, productID: String? = nil) {
        self.name = name
        self.kcal = per100g.kcal
        self.protein = per100g.protein
        self.fat = per100g.fat
        self.carbs = per100g.carbs
        self.packGrams = packGrams
        self.packPriceUAH = packPriceUAH
        self.createdAt = createdAt
        self.productID = productID
    }

    /// Stays the same across backups, so plan entries keep pointing at the product.
    var stableID: String { productID ?? "my-\(createdAt.timeIntervalSince1970)" }

    /// One portion for the plan: the pack, or 100 g.
    var planProduct: PlanProduct {
        let grams = packGrams > 0 ? packGrams : 100
        return PlanProduct(id: stableID, name: name, portion: per100g * (grams / 100), priceUAH: packPriceUAH)
    }

    var per100g: Nutrition {
        get { Nutrition(kcal: kcal, protein: protein, fat: fat, carbs: carbs) }
        set {
            kcal = newValue.kcal
            protein = newValue.protein
            fat = newValue.fat
            carbs = newValue.carbs
        }
    }

    var food: Food {
        let pack = packGrams > 0 ? [HouseholdUnit(name: LocalizedText(en: "pack", uk: "упаковка"), grams: packGrams)] : []
        return Food(id: stableID, name: LocalizedText(en: name, uk: name), per100g: per100g, units: pack)
    }
}

/// One meal of the shopping-trip plan (D-017). Auto-fill rewrites entries unless the owner set
/// them by hand or the dish was already cooked.
@Model
final class PlanEntry {
    /// Start of the day.
    var day: Date
    var mealRaw: String
    var recipeID: String?
    /// A product from "My products" planned as a snack.
    var productID: String?
    /// 1 for the second snack of a day.
    var number: Int = 0
    var isOutside: Bool
    var isManual: Bool
    var cookedAt: Date?

    init(day: Date, meal: MealType, number: Int = 0, recipeID: String?, productID: String? = nil, isOutside: Bool = false, isManual: Bool) {
        self.day = day
        self.mealRaw = meal.rawValue
        self.number = number
        self.recipeID = recipeID
        self.productID = productID
        self.isOutside = isOutside
        self.isManual = isManual
    }

    var meal: MealType { MealType(rawValue: mealRaw) ?? .lunch }

    var fill: SlotFill? {
        if isOutside { return .outside }
        if let productID { return .product(productID) }
        return recipeID.map(SlotFill.recipe)
    }
}

/// Ticked on the shopping list while in the store; moved into the fridge on the owner's tap.
@Model
final class BoughtItem {
    @Attribute(.unique) var ingredientID: String

    init(ingredientID: String) {
        self.ingredientID = ingredientID
    }
}
