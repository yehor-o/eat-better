import Foundation

/// Anything that can be logged by weight: a typical dish, a catalog ingredient or a product
/// the owner entered from a label (D-016).
public struct Food: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: LocalizedText
    public var per100g: Nutrition
    /// Natural portions; the first one is the default ("bowl", "cutlet", "pack").
    public var units: [HouseholdUnit]

    public init(id: String, name: LocalizedText, per100g: Nutrition, units: [HouseholdUnit] = []) {
        self.id = id
        self.name = name
        self.per100g = per100g
        self.units = units
    }

    public init(_ ingredient: Ingredient) {
        self.init(id: ingredient.id, name: ingredient.name, per100g: ingredient.per100g, units: ingredient.units)
    }

    public func nutrition(grams: Double) -> Nutrition {
        per100g * (grams / 100)
    }

    /// Grams of the default portion at a given size; 100 g when the food has no units.
    public func grams(of size: PortionSize) -> Double {
        ((units.first?.grams ?? 100) * size.factor).rounded()
    }
}

/// Rough portion size for food that was not weighed.
public enum PortionSize: String, CaseIterable, Sendable {
    case small, medium, large

    public var factor: Double {
        switch self {
        case .small: 0.7
        case .medium: 1
        case .large: 1.4
        }
    }
}

public extension Catalog {
    /// Typical dishes (borscht, cutlet, varenyky…) bundled with the package; approximate values.
    static func bundledDishes() throws -> [Food] {
        guard let url = Bundle.module.url(forResource: "dishes", withExtension: "json") else {
            throw CatalogError.missingResource("dishes")
        }
        return try JSONDecoder().decode([Food].self, from: Data(contentsOf: url))
    }
}
