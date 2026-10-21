import SwiftUI

struct PlanView: View {
    var body: some View {
        NavigationStack {
            // TODO(T-013, T-014): batch-cooking plan, shopping list, "what to buy for N days".
            ContentUnavailableView(
                "Coming next",
                systemImage: "cart",
                description: Text("Batch-cooking plan and shopping list will live here.")
            )
            .navigationTitle("Plan")
        }
    }
}
