import EatBetterCore
import SwiftData
import SwiftUI
import UIKit

/// Cooking mode (spec #8): one step at a time in large text, amounts for the chosen number of
/// portions, step timers.
/// The screen stays on while it is open.
struct CookingModeView: View {
    let recipe: Recipe
    let catalog: Catalog

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [ProfileRecord]
    @Binding var portions: Int
    @State private var page = 0
    @State private var timers: CookingTimers
    @State private var isConfirmingClose = false

    init(recipe: Recipe, catalog: Catalog, portions: Binding<Int>) {
        self.recipe = recipe
        self.catalog = catalog
        _portions = portions
        _timers = State(initialValue: CookingTimers(recipeID: recipe.id))
    }

    private var scaled: Recipe { recipe.scaled(toServings: portions) }
    private var lastPage: Int { recipe.steps.count + 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                runningTimers
                TabView(selection: $page) {
                    ingredientsPage.tag(0)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        stepPage(index: index, step: step).tag(index + 1)
                    }
                    donePage.tag(lastPage)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                navigationButtons
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        if timers.endsAt.isEmpty { dismiss() } else { isConfirmingClose = true }
                    }
                }
            }
            .confirmationDialog("Stop the timers and close?", isPresented: $isConfirmingClose, titleVisibility: .visible) {
                Button("Stop timers and close", role: .destructive) { timers.stopAll(); dismiss() }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            timers.stopAll()
        }
    }

    private var title: String {
        switch page {
        case 0: String(localized: "Ingredients")
        case lastPage: String(localized: "Done")
        default: String(localized: "Step \(page) of \(recipe.steps.count)")
        }
    }

    // MARK: Pages

    private var ingredientsPage: some View {
        List {
            Section {
                PortionStepper(portions: $portions)
                    .font(.title3)
                Text("\(recipe.totalMinutes) min")
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(scaled.ingredients, id: \.ingredientID) { item in
                    if let ingredient = catalog.ingredient(item.ingredientID) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: ingredient.name.current + (item.optional ? " " + String(localized: "(optional)") : ""))
                                .font(.title3)
                            Text(verbatim: catalog.amountText(ingredientID: item.ingredientID, grams: item.grams))
                                .font(.title3.bold())
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func stepPage(index: Int, step: RecipeStep) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(verbatim: step.text.current)
                    .font(.system(size: 30, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let minutes = step.timerMinutes {
                    timerControl(step: index, minutes: minutes, text: step.text.current)
                }
            }
            .padding(24)
        }
    }

    private func timerControl(step: Int, minutes: Int, text: String) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            if let left = timers.remaining(step: step, at: timeline.date) {
                VStack(spacing: 12) {
                    Text(verbatim: left > 0 ? left.clockText : String(localized: "Time is up"))
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(left > 0 ? Color.primary : Color.orange)
                    Button(left > 0 ? "Stop timer" : "Done", systemImage: left > 0 ? "stop.fill" : "checkmark") {
                        timers.stop(step: step)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity)
                .sensoryFeedback(.warning, trigger: left == 0)
            } else {
                Button {
                    timers.start(step: step, minutes: minutes, title: recipe.name.current,
                                 body: String(localized: "Timer done: step \(step + 1)") + " · " + text)
                } label: {
                    Label("Start \(minutes) min timer", systemImage: "timer")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    private var donePage: some View {
        let portions = scaled.servings
        return VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 64)).foregroundStyle(.green)
            Text("Enjoy your meal!").font(.title.bold())
            Spacer()
            Button {
                context.addCookedPortions(of: scaled, catalog: catalog, defaultStorageDays: storageDays)
                dismiss()
            } label: {
                Label("Cooked: \(portions) portions to Ready", systemImage: "refrigerator")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            Button {
                eatOneNow(portions: portions)
                dismiss()
            } label: {
                Group {
                    if portions > 1 {
                        Text("Eat 1 now, \(portions - 1) to Ready")
                    } else {
                        Text("Eat it now")
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.large)
        .padding(24)
    }

    // MARK: Controls

    @ViewBuilder
    private var runningTimers: some View {
        let others = timers.endsAt.keys.sorted().filter { $0 + 1 != page }
        if !others.isEmpty {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                HStack {
                    ForEach(others, id: \.self) { step in
                        let left = timers.remaining(step: step, at: timeline.date) ?? 0
                        Button {
                            page = step + 1
                        } label: {
                            Label(String(localized: "Step \(step + 1)") + " " + (left > 0 ? left.clockText : "✓"), systemImage: "timer")
                                .monospacedDigit()
                        }
                        .buttonStyle(.bordered)
                        .tint(left > 0 ? .accentColor : .orange)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation { page = max(page - 1, 0) }
            } label: {
                Label("Back", systemImage: "chevron.left").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(page == 0)
            Button {
                withAnimation { page = min(page + 1, lastPage) }
            } label: {
                Label("Next", systemImage: "chevron.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(page == lastPage)
        }
        .controlSize(.large)
        .padding()
    }

    // MARK: Actions

    private var storageDays: Int { profiles.first?.defaultStorageDays ?? 7 }

    private func eatOneNow(portions: Int) {
        let perServing = catalog.nutritionPerServing(of: recipe)
        context.insert(MealLogEntry(title: recipe.name.current, recipeID: recipe.id, nutrition: perServing))
        if portions > 1 {
            context.addCookedPortions(of: recipe.scaled(toServings: portions - 1), catalog: catalog, defaultStorageDays: storageDays)
        } else {
            context.saveNow()
        }
    }
}
