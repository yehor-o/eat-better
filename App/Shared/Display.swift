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
