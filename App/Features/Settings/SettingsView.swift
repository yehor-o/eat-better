import EatBetterCore
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @Query private var profiles: [ProfileRecord]
    @AppStorage(AppLanguage.storageKey) private var language: AppLanguage = .automatic

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
                    // TODO(T-015): export / import backup (JSON).
                }
            }
            .navigationTitle("Settings")
        }
    }
}

private struct ProfileForm: View {
    @Bindable var profile: ProfileRecord

    var body: some View {
        Section("Profile") {
            Stepper(value: $profile.weightKg, in: 35...200, step: 0.5) {
                Text("Weight: \(profile.weightKg, specifier: "%.1f") kg")
            }
            Stepper(value: $profile.heightCm, in: 120...230, step: 1) {
                Text("Height: \(Int(profile.heightCm)) cm")
            }
            Stepper(value: $profile.ageYears, in: 14...100) {
                Text("Age: \(profile.ageYears)")
            }
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
    }
}
