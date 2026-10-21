import EatBetterCore
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Moves personal data between SwiftData and a `Backup` file (spec #12, T-015).
@MainActor
enum BackupStore {
    static let lastExportKey = "lastBackupExport"
    private static let weekdaysKey = "shoppingWeekdays"

    static func make(from context: ModelContext, defaults: UserDefaults = .standard) throws -> Backup {
        let profile = try context.fetch(FetchDescriptor<ProfileRecord>()).first.map {
            Backup.Profile(weightKg: $0.weightKg, heightCm: $0.heightCm, ageYears: $0.ageYears, sex: $0.sexRaw,
                           activity: $0.activityRaw, goal: $0.goalRaw, defaultStorageDays: $0.defaultStorageDays)
        }
        return Backup(
            profile: profile,
            settings: Backup.Settings(
                shoppingWeekdays: defaults.string(forKey: weekdaysKey) ?? "",
                language: defaults.string(forKey: AppLanguage.storageKey) ?? AppLanguage.automatic.rawValue
            ),
            fridge: try context.fetch(FetchDescriptor<PantryItem>()).map(\.ingredientID).sorted(),
            prices: try context.fetch(FetchDescriptor<PriceOverride>()).map {
                Backup.Price(ingredientID: $0.ingredientID, packPriceUAH: $0.packPriceUAH, packGrams: $0.packGrams)
            },
            products: try context.fetch(FetchDescriptor<MyProduct>(sortBy: [SortDescriptor(\.createdAt)])).map {
                Backup.Product(id: $0.stableID, name: $0.name, per100g: $0.per100g, packGrams: $0.packGrams,
                               packPriceUAH: $0.packPriceUAH, createdAt: $0.createdAt)
            },
            readyPortions: try context.fetch(FetchDescriptor<ReadyPortion>(sortBy: [SortDescriptor(\.cookedAt)])).map {
                Backup.Portion(recipeID: $0.recipeID, title: $0.title, nutrition: $0.nutrition, cookedAt: $0.cookedAt, expiresAt: $0.expiresAt)
            },
            log: try context.fetch(FetchDescriptor<MealLogEntry>(sortBy: [SortDescriptor(\.date)])).map {
                Backup.LogEntry(date: $0.date, title: $0.title, recipeID: $0.recipeID, nutrition: $0.nutrition)
            },
            plan: try context.fetch(FetchDescriptor<PlanEntry>(sortBy: [SortDescriptor(\.day)])).map {
                Backup.PlanItem(day: $0.day, meal: $0.mealRaw, number: $0.number, recipeID: $0.recipeID, productID: $0.productID,
                                isOutside: $0.isOutside, isManual: $0.isManual, cookedAt: $0.cookedAt)
            },
            bought: try context.fetch(FetchDescriptor<BoughtItem>()).map(\.ingredientID).sorted()
        )
    }

    enum Mode {
        /// The device ends up exactly like the file.
        case replace
        /// Keeps what is on the device and adds what the file has on top.
        case add
    }

    /// Writes the file into the store. Never runs without the owner's confirmation in the UI.
    static func restore(_ file: Backup, mode: Mode, into context: ModelContext, defaults: UserDefaults = .standard) throws {
        let backup = mode == .replace ? file : try make(from: context, defaults: defaults).adding(file)
        try context.delete(model: ProfileRecord.self)
        try context.delete(model: PantryItem.self)
        try context.delete(model: PriceOverride.self)
        try context.delete(model: MyProduct.self)
        try context.delete(model: ReadyPortion.self)
        try context.delete(model: MealLogEntry.self)
        try context.delete(model: PlanEntry.self)
        try context.delete(model: BoughtItem.self)
        // Unique ingredient ids must be gone before the same ids are inserted again.
        try context.save()

        if let p = backup.profile {
            let profile = ProfileRecord(weightKg: p.weightKg, heightCm: p.heightCm, ageYears: p.ageYears,
                                        defaultStorageDays: p.defaultStorageDays)
            profile.sexRaw = p.sex
            profile.activityRaw = p.activity
            profile.goalRaw = p.goal
            context.insert(profile)
        }
        if let settings = backup.settings {
            defaults.set(settings.shoppingWeekdays, forKey: weekdaysKey)
            let language = AppLanguage(rawValue: settings.language) ?? .automatic
            defaults.set(language.rawValue, forKey: AppLanguage.storageKey)
            language.apply(to: defaults)
        }
        for id in Set(backup.fridge) { context.insert(PantryItem(ingredientID: id)) }
        for id in Set(backup.bought) { context.insert(BoughtItem(ingredientID: id)) }
        var priced = Set<String>()
        for price in backup.prices where priced.insert(price.ingredientID).inserted {
            context.insert(PriceOverride(ingredientID: price.ingredientID, packPriceUAH: price.packPriceUAH, packGrams: price.packGrams))
        }
        for p in backup.products {
            context.insert(MyProduct(name: p.name, per100g: p.per100g, packGrams: p.packGrams, packPriceUAH: p.packPriceUAH,
                                     createdAt: p.createdAt, productID: p.id))
        }
        for p in backup.readyPortions {
            context.insert(ReadyPortion(title: p.title, recipeID: p.recipeID, nutrition: p.nutrition, cookedAt: p.cookedAt, expiresAt: p.expiresAt))
        }
        for e in backup.log {
            context.insert(MealLogEntry(date: e.date, title: e.title, recipeID: e.recipeID, nutrition: e.nutrition))
        }
        for item in backup.plan {
            let entry = PlanEntry(day: item.day, meal: MealType(rawValue: item.meal) ?? .lunch, number: item.number,
                                  recipeID: item.recipeID, productID: item.productID, isOutside: item.isOutside, isManual: item.isManual)
            entry.cookedAt = item.cookedAt
            context.insert(entry)
        }
        try context.save()
    }

    static func fileName(for date: Date = .now) -> String {
        let day = date.formatted(.iso8601.year().month().day())
        return "EatBetter-backup-\(day)"
    }
}

/// The backup as a document for the system file exporter.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
