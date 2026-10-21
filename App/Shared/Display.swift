import EatBetterCore
import SwiftUI

extension LocalizedText {
    /// Text in the app's current UI language.
    var current: String {
        resolved(languageCode: Bundle.main.preferredLocalizations.first)
    }
}

extension MealType {
    var title: LocalizedStringKey {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }
}

extension IngredientCategory {
    /// The same title as plain text, for search.
    var localizedName: String {
        switch self {
        case .meatFish: String(localized: "Meat & fish")
        case .dairyEggs: String(localized: "Dairy & eggs")
        case .grains: String(localized: "Grains & pasta")
        case .vegetables: String(localized: "Vegetables")
        case .fruits: String(localized: "Fruits")
        case .bakery: String(localized: "Bakery")
        case .oilsSpices: String(localized: "Oils & spices")
        case .canned: String(localized: "Canned")
        case .other: String(localized: "Other")
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .meatFish: "Meat & fish"
        case .dairyEggs: "Dairy & eggs"
        case .grains: "Grains & pasta"
        case .vegetables: "Vegetables"
        case .fruits: "Fruits"
        case .bakery: "Bakery"
        case .oilsSpices: "Oils & spices"
        case .canned: "Canned"
        case .other: "Other"
        }
    }
}

extension Sex {
    var title: LocalizedStringKey {
        switch self {
        case .male: "Male"
        case .female: "Female"
        }
    }
}

extension ActivityLevel {
    var title: LocalizedStringKey {
        switch self {
        case .sedentary: "Sedentary"
        case .light: "Light"
        case .moderate: "Moderate"
        case .active: "Active"
        }
    }
}

extension Goal {
    var title: LocalizedStringKey {
        switch self {
        case .gain: "Gain weight"
        case .maintain: "Maintain"
        }
    }
}

extension Catalog {
    /// "150 g · ≈ 3 × egg"; grams only when the ingredient has no household units.
    func amountText(ingredientID: String, grams: Double) -> String {
        let base = "\(Int(grams.rounded())) \(String(localized: "g"))"
        guard let household = householdAmount(ingredientID: ingredientID, grams: grams) else { return base }
        let count = household.count.formatted(.number.precision(.fractionLength(0...1)))
        // Unit names may carry their own brackets ("cup (250 ml)"), so no brackets around this part.
        return "\(base) · ≈ \(count) × \(household.unit.name.current)"
    }
}

/// Calories and macros, optionally against a target.
struct NutritionRows: View {
    let value: Nutrition
    var target: Nutrition?

    var body: some View {
        row("Calories", value.kcal, target?.kcal, unit: String(localized: "kcal"))
        row("Protein", value.protein, target?.protein, unit: String(localized: "g"))
        row("Fat", value.fat, target?.fat, unit: String(localized: "g"))
        row("Carbs", value.carbs, target?.carbs, unit: String(localized: "g"))
    }

    private func row(_ title: LocalizedStringKey, _ amount: Double, _ goal: Double?, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent(title) {
                if let goal {
                    Text(verbatim: "\(Int(amount.rounded())) / \(Int(goal.rounded())) \(unit)")
                } else {
                    Text(verbatim: "\(Int(amount.rounded())) \(unit)")
                }
            }
            if let goal, goal > 0 {
                ProgressView(value: min(amount / goal, 1))
            }
        }
    }
}
