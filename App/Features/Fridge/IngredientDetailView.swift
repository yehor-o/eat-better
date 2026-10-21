import EatBetterCore
import SwiftData
import SwiftUI

/// One ingredient: nutrition, household measures and its price, which the owner can replace
/// with what they see in the store (spec #2, T-011). The override stays on this device.
struct IngredientDetailView: View {
    /// As the catalog has it (with the private store prices, if bundled).
    let ingredient: Ingredient

    @Environment(\.modelContext) private var context
    @Query private var overrides: [PriceOverride]
    @State private var packGrams: Double?
    @State private var price: Double?
    @State private var savedAt: Date?

    private var override: PriceOverride? { overrides.first { $0.ingredientID == ingredient.id } }

    var body: some View {
        Form {
            Section("Per 100 g") {
                NutritionRows(value: ingredient.per100g)
            }

            if !ingredient.units.isEmpty {
                Section("Household measures") {
                    ForEach(ingredient.units, id: \.self) { unit in
                        LabeledContent(unit.name.current) {
                            Text(verbatim: "\(Int(unit.grams.rounded())) \(String(localized: "g"))")
                        }
                    }
                }
            }

            Section {
                LabeledContent("Catalog") {
                    Text(verbatim: packText(grams: ingredient.packGrams, price: ingredient.packPriceUAH))
                }
                if let override {
                    LabeledContent("Yours") {
                        Text(verbatim: packText(grams: override.packGrams > 0 ? override.packGrams : ingredient.packGrams, price: override.packPriceUAH))
                            .bold()
                    }
                }
            } header: {
                Text("Price")
            }

            Section {
                NumberField("Pack, g", value: $packGrams)
                NumberField("Price, ₴", value: $price)
                Button {
                    save()
                } label: {
                    if savedAt == nil {
                        Label("Save my price", systemImage: "checkmark.circle")
                    } else {
                        Label("Saved", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                }
                .disabled((price ?? 0) <= 0)
                .sensoryFeedback(.success, trigger: savedAt)
                if override != nil {
                    Button("Use the catalog price", systemImage: "arrow.uturn.backward", role: .destructive) { reset() }
                }
            } header: {
                Text("My price")
            } footer: {
                Text("What you see in your store. Stays only on this iPhone and is used for recipes, the plan and the shopping list.")
            }
        }
        .navigationTitle(ingredient.name.current)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: packGrams) { savedAt = nil }
        .onChange(of: price) { savedAt = nil }
    }

    private func packText(grams: Double, price: Double) -> String {
        "\(Int(grams.rounded())) \(String(localized: "g")) · ~\(price.formatted(.number.precision(.fractionLength(0...2)).grouping(.never))) ₴"
    }

    private func load() {
        if let override {
            packGrams = override.packGrams > 0 ? override.packGrams : ingredient.packGrams
            price = override.packPriceUAH
        } else {
            packGrams = ingredient.packGrams
            price = ingredient.packPriceUAH
        }
    }

    private func save() {
        guard let price, price > 0 else { return }
        // A pack equal to the catalog one is stored as "catalog pack", so a later catalog change still applies.
        let grams = (packGrams ?? 0) > 0 && packGrams != ingredient.packGrams ? packGrams! : 0
        if let override {
            override.packPriceUAH = price
            override.packGrams = grams
        } else {
            context.insert(PriceOverride(ingredientID: ingredient.id, packPriceUAH: price, packGrams: grams))
        }
        context.saveNow()
        savedAt = .now
    }

    private func reset() {
        if let override { context.delete(override) }
        context.saveNow()
        packGrams = ingredient.packGrams
        price = ingredient.packPriceUAH
        savedAt = nil
    }
}
