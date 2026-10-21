import EatBetterCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query private var profiles: [ProfileRecord]
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .automatic
    @AppStorage(BackupStore.lastExportKey) private var lastExport: Double = 0

    @State private var exportDocument: BackupDocument?
    @State private var isImporting = false
    @State private var pendingImport: Backup?
    @State private var backupMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                if let profile = profiles.first {
                    ProfileForm(profile: profile)
                } else {
                    Section {
                        Button("Set up profile") { context.insert(ProfileRecord()) }
                    }
                }

                Section {
                    Picker("Language", selection: $language) {
                        ForEach(AppLanguage.allCases, id: \.self) { $0.title.tag($0) }
                    }
                    .onChange(of: language) { _, new in new.apply() }
                } footer: {
                    Text("Takes effect after you close and reopen the app.")
                }

                Section("Data") {
                    LabeledContent("Recipes") {
                        store.isUsingDemoRecipes ? Text("Demo set") : Text("Private file")
                    }
                    LabeledContent("Ingredients") {
                        Text(verbatim: "\(store.catalog?.ingredients.count ?? 0)")
                    }
                    if store.privatePriceCount > 0 {
                        LabeledContent("Store prices") {
                            Text(verbatim: "\(store.privatePriceCount)")
                        }
                    }
                }

                Section {
                    Button("Export backup", systemImage: "square.and.arrow.up") { export() }
                    Button("Import backup", systemImage: "square.and.arrow.down") { isImporting = true }
                } header: {
                    Text("Backup")
                } footer: {
                    if lastExport > 0 {
                        Text("Last export: \(Date(timeIntervalSince1970: lastExport).formatted(date: .abbreviated, time: .shortened)). Save the file in Files or iCloud Drive.")
                    } else {
                        Text("No backup yet. Export one before reinstalling the app. Save the file in Files or iCloud Drive.")
                    }
                }
            }
            .navigationTitle("Settings")
            .numberKeyboardDone()
            .fileExporter(
                isPresented: Binding(get: { exportDocument != nil }, set: { if !$0 { exportDocument = nil } }),
                document: exportDocument,
                contentType: .json,
                defaultFilename: BackupStore.fileName()
            ) { result in
                switch result {
                case .success:
                    lastExport = Date.now.timeIntervalSince1970
                    backupMessage = String(localized: "Backup saved.")
                case .failure(let error):
                    backupMessage = error.localizedDescription
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                read(result)
            }
            .confirmationDialog("Import backup?", isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
                                titleVisibility: .visible, presenting: pendingImport) { backup in
                Button("Replace everything", role: .destructive) { restore(backup, mode: .replace) }
                Button("Add to what is here") { restore(backup, mode: .add) }
            } message: { backup in
                Text(summary(of: backup))
            }
            .alert("Backup", isPresented: Binding(get: { backupMessage != nil }, set: { if !$0 { backupMessage = nil } })) {
                Button("OK") {}
            } message: {
                Text(verbatim: backupMessage ?? "")
            }
        }
    }

    private func export() {
        do {
            context.saveNow()
            exportDocument = BackupDocument(data: try BackupStore.make(from: context).encoded())
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func read(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            pendingImport = try Backup.decode(Data(contentsOf: url))
        } catch Backup.FileError.newerVersion {
            backupMessage = String(localized: "This backup comes from a newer version of the app.")
        } catch {
            backupMessage = String(localized: "Could not read this file as a backup.")
        }
    }

    private func restore(_ backup: Backup, mode: BackupStore.Mode) {
        do {
            try BackupStore.restore(backup, mode: mode, into: context)
            backupMessage = String(localized: "Backup imported.")
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func summary(of backup: Backup) -> String {
        let date = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
        return String(localized: "File from \(date): \(backup.fridge.count) fridge items, \(backup.products.count) products, \(backup.prices.count) prices, \(backup.readyPortions.count) ready portions, \(backup.log.count) log entries, \(backup.plan.count) plan meals.")
            + "\n\n" + String(localized: "Replace: the app becomes exactly like the file. Add: nothing is removed, missing items are added.")
    }
}

private struct ProfileForm: View {
    @Bindable var profile: ProfileRecord
    @Environment(\.modelContext) private var context

    var body: some View {
        Section("Profile") {
            // Typed, not stepped: a new profile starts at 70 kg / 175 cm / 25 y.
            NumberField("Weight, kg", value: number(\.weightKg, in: 35...200))
            NumberField("Height, cm", value: number(\.heightCm, in: 120...230))
            NumberField("Age, years", value: Binding(
                get: { Double(profile.ageYears) },
                set: { if let new = $0, (14...100).contains(new) { profile.ageYears = Int(new) } }
            ))
            Picker("Sex", selection: $profile.sex) {
                ForEach(Sex.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Activity", selection: $profile.activity) {
                ForEach(ActivityLevel.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Picker("Goal", selection: $profile.goal) {
                ForEach(Goal.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Stepper(value: $profile.defaultStorageDays, in: 1...14) {
                Text("Cooked food keeps: ^[\(profile.defaultStorageDays) day](inflect: true)")
            }
        }

        Section("Daily targets") {
            NutritionRows(value: DailyTargets.targets(for: profile.bodyProfile))
        }
        // Every change is written at once (D-019), so a quick app kill keeps the new profile.
        .onChange(of: profile.bodyProfile) { context.saveNow() }
        .onChange(of: profile.defaultStorageDays) { context.saveNow() }
    }

    /// Keeps the last valid value while the owner is still typing (e.g. "1" on the way to "183").
    private func number(_ keyPath: ReferenceWritableKeyPath<ProfileRecord, Double>, in range: ClosedRange<Double>) -> Binding<Double?> {
        Binding(
            get: { profile[keyPath: keyPath] },
            set: { if let new = $0, range.contains(new) { profile[keyPath: keyPath] = new } }
        )
    }
}
