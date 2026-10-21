import SwiftData
import SwiftUI
import UserNotifications

@main
struct EatBetterApp: App {
    @State private var catalogStore = CatalogStore()

    init() {
        UNUserNotificationCenter.current().delegate = TimerNotificationDelegate.shared
    }

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
            MyProduct.self,
            PlanEntry.self,
            BoughtItem.self,
        ])
    }
}

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") { TodayView() }
            Tab("Recipes", systemImage: "book") { RecipesView() }
            Tab("Fridge", systemImage: "refrigerator") { FridgeView() }
            Tab("Plan", systemImage: "cart") { PlanView() }
            Tab("Settings", systemImage: "gearshape") { SettingsView() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { context.saveNow() }
        }
    }
}
