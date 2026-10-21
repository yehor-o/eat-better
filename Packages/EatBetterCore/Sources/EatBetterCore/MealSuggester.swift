import Foundation

public extension MealType {
    /// The meal that fits a time of day: breakfast until 11, lunch until 16, dinner until 21,
    /// snack otherwise.
    static func at(hour: Int) -> MealType {
        switch hour {
        case 5..<11: .breakfast
        case 11..<16: .lunch
        case 16..<21: .dinner
        default: .snack
        }
    }
}

/// A portion waiting in the fridge, as the suggester sees it.
public struct ReadyItem: Hashable, Sendable {
    public var id: String
    public var title: String
    public var nutrition: Nutrition
    public var expiresAt: Date

    public init(id: String, title: String, nutrition: Nutrition, expiresAt: Date) {
        self.id = id
        self.title = title
        self.nutrition = nutrition
        self.expiresAt = expiresAt
    }
}

public struct MealSuggestion: Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        /// Eat a portion that is already cooked.
        case ready(id: String)
        /// Everything needed is in the fridge.
        case cookNow(recipeID: String)
        /// One ingredient has to be bought first.
        case buyFirst(recipeID: String, missing: [Ingredient])
    }

    public enum Reason: Hashable, Sendable {
        case alreadyCooked
        case eatSoon
        case fitsMeal(MealType)
        case proteinRich
        case quick
    }

    public var kind: Kind
    public var title: LocalizedText
    /// One serving / portion.
    public var nutrition: Nutrition
    public var minutes: Int?
    public var reasons: [Reason]
    public var score: Double
}

/// "What should I eat now?" (spec #7): ranks ready portions and recipes by time of day,
/// the fridge, what is still missing for the day's protein, and variety.
public enum MealSuggester {
    public struct Context: Sendable {
        public var now: Date
        public var calendar: Calendar
        public var ready: [ReadyItem]
        public var pantry: PantryMatches
        /// Eaten so far today.
        public var eaten: Nutrition
        /// Daily target; `nil` when no profile is set up.
        public var target: Nutrition?
        /// Recipes eaten in the last day, to avoid offering the same dish again.
        public var recentRecipeIDs: Set<String>

        public init(
            now: Date,
            calendar: Calendar = .current,
            ready: [ReadyItem],
            pantry: PantryMatches,
            eaten: Nutrition,
            target: Nutrition?,
            recentRecipeIDs: Set<String> = []
        ) {
            self.now = now
            self.calendar = calendar
            self.ready = ready
            self.pantry = pantry
            self.eaten = eaten
            self.target = target
            self.recentRecipeIDs = recentRecipeIDs
        }
    }

    /// Best first. Empty when there is nothing ready and nothing to cook with at most one purchase.
    public static func suggestions(_ context: Context, catalog: Catalog) -> [MealSuggestion] {
        let meal = MealType.at(hour: context.calendar.component(.hour, from: context.now))
        let proteinLeft = context.target.map { max($0.protein - context.eaten.protein, 0) }
        var result: [MealSuggestion] = []

        // Cooked food first: no effort, and it should not go to waste.
        for item in context.ready {
            var reasons: [MealSuggestion.Reason] = [.alreadyCooked]
            var score = 3.0
            let hoursLeft = item.expiresAt.timeIntervalSince(context.now) / 3600
            if hoursLeft < 36 {
                reasons.append(.eatSoon)
                score += 2
            }
            score += proteinBonus(item.nutrition, proteinLeft: proteinLeft, reasons: &reasons)
            result.append(MealSuggestion(
                kind: .ready(id: item.id),
                title: LocalizedText(en: item.title, uk: item.title),
                nutrition: item.nutrition, minutes: nil, reasons: reasons, score: score
            ))
        }

        let cookable = context.pantry.canCookNow.map { ($0, 1.5) }
            + context.pantry.almost.filter { $0.missing.count == 1 }.map { ($0, 0.0) }
        for (match, base) in cookable {
            let recipe = match.recipe
            guard fits(recipe, meal: meal) else { continue }
            let nutrition = catalog.nutritionPerServing(of: recipe)
            var reasons: [MealSuggestion.Reason] = [.fitsMeal(meal)]
            var score = base + 1
            if recipe.totalMinutes <= 15 {
                reasons.append(.quick)
                score += 0.5
            }
            score += proteinBonus(nutrition, proteinLeft: proteinLeft, reasons: &reasons)
            if context.recentRecipeIDs.contains(recipe.id) { score -= 1.5 }
            result.append(MealSuggestion(
                kind: match.canCookNow ? .cookNow(recipeID: recipe.id) : .buyFirst(recipeID: recipe.id, missing: match.missing),
                title: recipe.name, nutrition: nutrition, minutes: recipe.totalMinutes,
                reasons: reasons, score: score
            ))
        }

        return result.sorted { ($0.score, $1.title.en) > ($1.score, $0.title.en) }
    }

    /// Breakfast and snack dishes are interchangeable; lunch and dinner too.
    public static func fits(_ recipe: Recipe, meal: MealType) -> Bool {
        let fitting: Set<MealType> = switch meal {
        case .breakfast, .snack: [.breakfast, .snack]
        case .lunch, .dinner: [.lunch, .dinner]
        }
        return !fitting.isDisjoint(with: recipe.mealTypes)
    }

    /// Up to +1.5 for portions that cover a good share of the protein still missing today.
    private static func proteinBonus(_ n: Nutrition, proteinLeft: Double?, reasons: inout [MealSuggestion.Reason]) -> Double {
        guard n.protein >= 20 else { return 0 }
        reasons.append(.proteinRich)
        guard let proteinLeft, proteinLeft > 0 else { return 0.5 }
        return min(n.protein / proteinLeft * 3, 1.5)
    }
}
