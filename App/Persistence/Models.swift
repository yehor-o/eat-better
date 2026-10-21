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

/// Per-device pack price that replaces the catalog estimate.
@Model
final class PriceOverride {
    @Attribute(.unique) var ingredientID: String
    var packPriceUAH: Double

    init(ingredientID: String, packPriceUAH: Double) {
        self.ingredientID = ingredientID
        self.packPriceUAH = packPriceUAH
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

/// One cooked portion waiting in the fridge.
@Model
final class ReadyPortion {
    var recipeID: String
    var cookedAt: Date
    var expiresAt: Date

    init(recipeID: String, cookedAt: Date = .now, expiresAt: Date) {
        self.recipeID = recipeID
        self.cookedAt = cookedAt
        self.expiresAt = expiresAt
    }
}
