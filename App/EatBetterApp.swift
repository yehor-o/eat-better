import SwiftData
import SwiftUI

@main
struct EatBetterApp: App {
    @State private var catalogStore = CatalogStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(catalogStore)
        }
        .modelContainer(for: [
            ProfileRecord.self,
            PantryItem.self,
            PriceOverride.self,
            MealLogEntry.self,
            ReadyPortion.self,
        ])
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") { TodayView() }
            Tab("Recipes", systemImage: "book") { RecipesView() }
            Tab("Fridge", systemImage: "refrigerator") { FridgeView() }
            Tab("Plan", systemImage: "cart") { PlanView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
    }
}
