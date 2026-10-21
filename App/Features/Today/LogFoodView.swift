import EatBetterCore
import SwiftData
import SwiftUI
import UIKit

/// Log any food, cooked here or not (D-016): paste from Claude, recent, my products,
/// typical dishes, basic foods, or plain numbers.
struct LogFoodView: View {
    @Environment(CatalogStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MyProduct.name) private var products: [MyProduct]
    @Query(sort: \MealLogEntry.date, order: .reverse) private var log: [MealLogEntry]

    @State private var search = ""
    @State private var pasted: [ClaudeFoodCode] = []
    @State private var pasteFoundNothing = false
    @State private var promptCopied = false

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    claudeSection
                    recentSection
                }
                productsSection
                foodSection("Typical dishes", foods: store.dishes)
                foodSection("Basic foods", foods: basicFoods)
                Section {
                    NavigationLink("Enter numbers manually") { ManualFoodView(done: { dismiss() }) }
                }
            }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: Sections

    private var claudeSection: some View {
        Section {
            PasteButton(payloadType: String.self) { strings in
                let codes = ClaudeFoodCode.parseAll(strings.joined(separator: "\n"))
                Task { @MainActor in
                    pasted = codes
                    pasteFoundNothing = codes.isEmpty
                }
            }
            ForEach(Array(pasted.enumerated()), id: \.offset) { _, code in
                NavigationLink {
                    ManualFoodView(prefill: code, done: { dismiss() })
                } label: {
                    LabeledContent(code.title) {
                        Text(verbatim: "\(Int(code.perServing.kcal.rounded())) \(String(localized: "kcal"))")
                    }
                }
            }
            if pasteFoundNothing {
                Text("No Eat Better code in the copied text.").foregroundStyle(.secondary)
            }
            Button(promptCopied ? "Prompt copied" : "Copy the prompt for Claude",
                   systemImage: promptCopied ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = String(localized: "claude.prompt")
                promptCopied = true
            }
        } header: {
            Text("Paste from Claude")
        } footer: {
            Text("In the Claude app paste the prompt, add a photo or a description, then copy Claude's answer and tap Paste.")
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let recent = recentEntries
        if !recent.isEmpty {
            Section("Eat again") {
                ForEach(recent) { entry in
                    Button {
                        context.insert(MealLogEntry(title: entry.title, recipeID: entry.recipeID, nutrition: entry.nutrition))
                        dismiss()
                    } label: {
                        LabeledContent {
                            Text(verbatim: "\(Int(entry.kcal.rounded())) \(String(localized: "kcal"))")
                        } label: {
                            Label(entry.title, systemImage: "plus.circle")
                        }
                    }
                }
            }
        }
    }

    private var productsSection: some View {
        Section {
            ForEach(products.filter { matches($0.name) }) { product in
                NavigationLink {
                    FoodAmountView(food: product.food, title: product.name, showsSizes: false, done: { dismiss() })
                } label: {
                    Text(product.name)
                }
                .swipeActions {
                    Button("Delete", role: .destructive) { context.delete(product) }
                    NavigationLink("Edit") { MyProductForm(product: product) }
                }
            }
            NavigationLink { MyProductForm() } label: {
                Label("Add a product from its label", systemImage: "plus")
            }
        } header: {
            Text("My products")
        } footer: {
            if products.isEmpty {
                Text("Yogurts, kefir, bars and other snacks: enter the label once, then log in one tap.")
            }
        }
    }

    @ViewBuilder
    private func foodSection(_ title: LocalizedStringKey, foods: [Food]) -> some View {
        let shown = foods.filter { matches($0.name.current) }.sorted { $0.name.current < $1.name.current }
        if !shown.isEmpty {
            Section(title) {
                ForEach(shown) { food in
                    NavigationLink(food.name.current) {
                        FoodAmountView(food: food, title: food.name.current, done: { dismiss() })
                    }
                }
            }
        }
    }

    // MARK: Data

    private var basicFoods: [Food] {
        store.catalog?.ingredients.values.map(Food.init) ?? []
    }

    /// Latest distinct foods from the log, so a regular snack is one tap away.
    private var recentEntries: [MealLogEntry] {
        var seen = Set<String>()
        return log.filter { seen.insert($0.title).inserted }.prefix(5).map { $0 }
    }

    private func matches(_ name: String) -> Bool {
        search.isEmpty || name.localizedCaseInsensitiveContains(search)
    }
}
