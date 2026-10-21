import EatBetterCore
import SwiftData
import SwiftUI

/// What to buy for the plan, ticked off in the store; bought items go to the fridge on one tap.
struct ShoppingListView: View {
    let plan: ShoppingPlan
    let catalog: Catalog

    @Environment(\.modelContext) private var context
    @Query private var bought: [BoughtItem]
    @State private var isConfirmingFridge = false

    var body: some View {
        let boughtIDs = Set(bought.map(\.ingredientID))
        let toFridge = plan.list.items.filter { boughtIDs.contains($0.ingredient.id) }
        List {
            if plan.list.items.isEmpty && plan.products.isEmpty {
                Text("Nothing to buy: everything for the plan is in the fridge.")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    LabeledContent("Total, approximately") {
                        Text(verbatim: "~\(Int(plan.totalUAH.rounded())) ₴").bold()
                    }
                }
                ForEach(IngredientCategory.allCases, id: \.self) { category in
                    let items = plan.list.items.filter { $0.ingredient.category == category }
                    if !items.isEmpty {
                        Section(category.title) {
                            ForEach(items, id: \.ingredient.id) { item in
                                itemRow(item, isBought: boughtIDs.contains(item.ingredient.id))
                            }
                        }
                    }
                }
            }

            if !plan.products.isEmpty {
                Section {
                    ForEach(plan.products, id: \.product.id) { purchase in
                        LabeledContent {
                            if let cost = purchase.costUAH {
                                Text(verbatim: "~\(Int(cost.rounded())) ₴")
                            } else {
                                Text("no price")
                            }
                        } label: {
                            Text(verbatim: "\(purchase.product.name) × \(purchase.count)")
                        }
                    }
                } header: {
                    Text("My products")
                } footer: {
                    Text("Snacks from My products. Add a pack price in My products to count them in the total.")
                }
            }

            if !plan.checkAtHome.isEmpty {
                Section {
                    ForEach(plan.checkAtHome, id: \.ingredient.id) { entry in
                        LabeledContent(entry.ingredient.name.current) {
                            Text(verbatim: catalog.amountText(ingredientID: entry.ingredient.id, grams: entry.grams))
                        }
                    }
                } header: {
                    Text("Check at home")
                } footer: {
                    Text("These are ticked in the fridge. Make sure there is enough.")
                }
            }

            if !toFridge.isEmpty {
                Section {
                    Button("Put bought items in the fridge (\(toFridge.count))", systemImage: "refrigerator") {
                        isConfirmingFridge = true
                    }
                }
            }
        }
        .navigationTitle("Shopping list")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Tick these in the fridge?", isPresented: $isConfirmingFridge, titleVisibility: .visible) {
            Button("Put \(toFridge.count) items in the fridge") { putInFridge(toFridge) }
        } message: {
            Text(verbatim: toFridge.map(\.ingredient.name.current).joined(separator: ", "))
        }
    }

    private func itemRow(_ item: ShoppingItem, isBought: Bool) -> some View {
        Button {
            toggle(item.ingredient.id, isBought: isBought)
        } label: {
            HStack {
                Image(systemName: isBought ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isBought ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.ingredient.name.current)
                        .foregroundStyle(.primary)
                        .strikethrough(isBought)
                    Text("\(item.packs) × \(Int(item.ingredient.packGrams)) g · need \(Int(item.gramsNeeded.rounded())) g")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(verbatim: "~\(Int(item.costUAH.rounded())) ₴").foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
    }

    private func toggle(_ id: String, isBought: Bool) {
        if isBought {
            bought.filter { $0.ingredientID == id }.forEach { context.delete($0) }
        } else {
            context.insert(BoughtItem(ingredientID: id))
        }
        context.saveNow()
    }

    /// Only on the owner's tap (D-006, D-017).
    private func putInFridge(_ items: [ShoppingItem]) {
        for item in items {
            context.insert(PantryItem(ingredientID: item.ingredient.id))
        }
        bought.forEach { context.delete($0) }
        context.saveNow()
    }
}
