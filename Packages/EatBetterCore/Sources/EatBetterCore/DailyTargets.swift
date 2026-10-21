import Foundation

public enum Sex: String, Codable, CaseIterable, Sendable {
    case male, female
}

public enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary, light, moderate, active

    var multiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        }
    }
}

public enum Goal: String, Codable, CaseIterable, Sendable {
    case gain, maintain

    var kcalAdjustment: Double {
        switch self {
        case .gain: 400
        case .maintain: 0
        }
    }
}

public struct BodyProfile: Codable, Hashable, Sendable {
    public var weightKg: Double
    public var heightCm: Double
    public var ageYears: Int
    public var sex: Sex
    public var activity: ActivityLevel
    public var goal: Goal

    public init(weightKg: Double, heightCm: Double, ageYears: Int, sex: Sex, activity: ActivityLevel, goal: Goal) {
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.ageYears = ageYears
        self.sex = sex
        self.activity = activity
        self.goal = goal
    }
}

/// Daily calorie and macro targets. See docs/DECISIONS.md (D-007) for the formula choice.
public enum DailyTargets {
    public static let proteinGramsPerKg = 1.8
    public static let fatGramsPerKg = 1.0

    /// Basal metabolic rate, Mifflin–St Jeor.
    public static func bmr(for p: BodyProfile) -> Double {
        let base = 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.ageYears)
        return base + (p.sex == .male ? 5 : -161)
    }

    public static func targets(for p: BodyProfile) -> Nutrition {
        let kcal = bmr(for: p) * p.activity.multiplier + p.goal.kcalAdjustment
        let protein = p.weightKg * proteinGramsPerKg
        let fat = p.weightKg * fatGramsPerKg
        let carbs = max(0, (kcal - protein * 4 - fat * 9) / 4)
        return Nutrition(kcal: kcal, protein: protein, fat: fat, carbs: carbs)
    }
}
