import Foundation

/// Everything personal the app keeps on the device, as one JSON file (spec #12).
/// Sections missing from a file decode as empty, so a partial file (e.g. only the fridge) imports.
public struct Backup: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public struct Profile: Codable, Equatable, Sendable {
        public var weightKg: Double
        public var heightCm: Double
        public var ageYears: Int
        public var sex: String
        public var activity: String
        public var goal: String
        public var defaultStorageDays: Int

        public init(weightKg: Double, heightCm: Double, ageYears: Int, sex: String, activity: String, goal: String, defaultStorageDays: Int) {
            self.weightKg = weightKg
            self.heightCm = heightCm
            self.ageYears = ageYears
            self.sex = sex
            self.activity = activity
            self.goal = goal
            self.defaultStorageDays = defaultStorageDays
        }
    }

    public struct Settings: Codable, Equatable, Sendable {
        /// Calendar weekdays, comma-separated, as the Plan tab stores them.
        public var shoppingWeekdays: String
        public var language: String

        public init(shoppingWeekdays: String, language: String) {
            self.shoppingWeekdays = shoppingWeekdays
            self.language = language
        }
    }

    public struct Price: Codable, Equatable, Sendable {
        public var ingredientID: String
        public var packPriceUAH: Double
        /// 0 means the catalog pack.
        public var packGrams: Double

        public init(ingredientID: String, packPriceUAH: Double, packGrams: Double = 0) {
            self.ingredientID = ingredientID
            self.packPriceUAH = packPriceUAH
            self.packGrams = packGrams
        }
    }

    public struct Product: Codable, Equatable, Sendable {
        public var id: String
        public var name: String
        public var per100g: Nutrition
        public var packGrams: Double
        public var packPriceUAH: Double?
        public var createdAt: Date

        public init(id: String, name: String, per100g: Nutrition, packGrams: Double, packPriceUAH: Double?, createdAt: Date) {
            self.id = id
            self.name = name
            self.per100g = per100g
            self.packGrams = packGrams
            self.packPriceUAH = packPriceUAH
            self.createdAt = createdAt
        }
    }

    public struct Portion: Codable, Equatable, Sendable {
        public var recipeID: String?
        public var title: String
        public var nutrition: Nutrition
        public var cookedAt: Date
        public var expiresAt: Date

        public init(recipeID: String?, title: String, nutrition: Nutrition, cookedAt: Date, expiresAt: Date) {
            self.recipeID = recipeID
            self.title = title
            self.nutrition = nutrition
            self.cookedAt = cookedAt
            self.expiresAt = expiresAt
        }
    }

    public struct LogEntry: Codable, Equatable, Sendable {
        public var date: Date
        public var title: String
        public var recipeID: String?
        public var nutrition: Nutrition

        public init(date: Date, title: String, recipeID: String?, nutrition: Nutrition) {
            self.date = date
            self.title = title
            self.recipeID = recipeID
            self.nutrition = nutrition
        }
    }

    public struct PlanItem: Codable, Equatable, Sendable {
        public var day: Date
        public var meal: String
        /// 0 for the first snack of a day, 1 for the second; 0 for main meals.
        public var number: Int
        public var recipeID: String?
        public var productID: String?
        public var isOutside: Bool
        public var isManual: Bool
        public var cookedAt: Date?

        public init(day: Date, meal: String, number: Int = 0, recipeID: String?, productID: String? = nil,
                    isOutside: Bool, isManual: Bool, cookedAt: Date?) {
            self.day = day
            self.meal = meal
            self.number = number
            self.recipeID = recipeID
            self.productID = productID
            self.isOutside = isOutside
            self.isManual = isManual
            self.cookedAt = cookedAt
        }
    }

    public var version: Int
    public var exportedAt: Date
    public var profile: Profile?
    public var settings: Settings?
    public var fridge: [String]
    public var prices: [Price]
    public var products: [Product]
    public var readyPortions: [Portion]
    public var log: [LogEntry]
    public var plan: [PlanItem]
    public var bought: [String]

    public init(
        exportedAt: Date = .now,
        profile: Profile? = nil,
        settings: Settings? = nil,
        fridge: [String] = [],
        prices: [Price] = [],
        products: [Product] = [],
        readyPortions: [Portion] = [],
        log: [LogEntry] = [],
        plan: [PlanItem] = [],
        bought: [String] = []
    ) {
        self.version = Self.currentVersion
        self.exportedAt = exportedAt
        self.profile = profile
        self.settings = settings
        self.fridge = fridge
        self.prices = prices
        self.products = products
        self.readyPortions = readyPortions
        self.log = log
        self.plan = plan
        self.bought = bought
    }

    enum CodingKeys: String, CodingKey {
        case version, exportedAt, profile, settings, fridge, prices, products, readyPortions, log, plan, bought
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Self.currentVersion
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? .now
        profile = try c.decodeIfPresent(Profile.self, forKey: .profile)
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings)
        fridge = try c.decodeIfPresent([String].self, forKey: .fridge) ?? []
        prices = try c.decodeIfPresent([Price].self, forKey: .prices) ?? []
        products = try c.decodeIfPresent([Product].self, forKey: .products) ?? []
        readyPortions = try c.decodeIfPresent([Portion].self, forKey: .readyPortions) ?? []
        log = try c.decodeIfPresent([LogEntry].self, forKey: .log) ?? []
        plan = try c.decodeIfPresent([PlanItem].self, forKey: .plan) ?? []
        bought = try c.decodeIfPresent([String].self, forKey: .bought) ?? []
    }

    // MARK: File

    public enum FileError: Error, Equatable {
        case newerVersion(Int)
    }

    /// Dates keep Foundation's own encoding (seconds since 2001), so they come back bit for bit and
    /// re-importing a file never doubles log entries or portions.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> Backup {
        let backup = try JSONDecoder().decode(Backup.self, from: data)
        guard backup.version <= currentVersion else { throw FileError.newerVersion(backup.version) }
        return backup
    }

    // MARK: Merge

    /// "Add to current": keeps everything that is already on the device and adds what the file
    /// has on top. On a conflict (same ingredient, product, plan slot) the device wins; identical
    /// log entries and portions are not doubled, so importing the same file twice changes nothing.
    public func adding(_ other: Backup) -> Backup {
        var result = self
        result.profile = profile ?? other.profile
        result.settings = settings ?? other.settings
        result.fridge = Self.union(fridge, other.fridge)
        result.bought = Self.union(bought, other.bought)

        let priced = Set(prices.map(\.ingredientID))
        result.prices += other.prices.filter { !priced.contains($0.ingredientID) }

        let productIDs = Set(products.map(\.id))
        result.products += other.products.filter { !productIDs.contains($0.id) }

        for portion in other.readyPortions where !result.readyPortions.contains(portion) {
            result.readyPortions.append(portion)
        }
        for entry in other.log where !result.log.contains(entry) {
            result.log.append(entry)
        }

        let slots = Set(plan.map { PlanKey(day: $0.day, meal: $0.meal, number: $0.number) })
        result.plan += other.plan.filter { !slots.contains(PlanKey(day: $0.day, meal: $0.meal, number: $0.number)) }
        return result
    }

    private struct PlanKey: Hashable {
        var day: Date
        var meal: String
        var number: Int
    }

    private static func union(_ a: [String], _ b: [String]) -> [String] {
        var seen = Set(a)
        return a + b.filter { seen.insert($0).inserted }
    }
}
