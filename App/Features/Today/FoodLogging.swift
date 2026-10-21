import EatBetterCore
import SwiftData
import SwiftUI

/// How a logged food is split between "eaten now" and portions kept in "Ready" (D-016).
struct ServingPlan {
    var isContainer = false
    var servings = 2
    var eatNow = true
    var keepDays = 3

    @MainActor
    func log(title: String, perServing: Nutrition, recipeID: String? = nil, in context: ModelContext) {
        if !isContainer || eatNow {
            context.insert(MealLogEntry(title: title, recipeID: recipeID, nutrition: perServing))
        }
        guard isContainer else {
            context.saveNow()
            return
        }
        let toStore = servings - (eatNow ? 1 : 0)
        let expires = Calendar.current.date(byAdding: .day, value: keepDays, to: .now) ?? .now
        for _ in 0..<max(toStore, 0) {
            context.insert(ReadyPortion(title: title, recipeID: recipeID, nutrition: perServing, expiresAt: expires))
        }
        context.saveNow()
    }
}

/// "Several portions" switch shared by every log form.
struct ServingPlanSection: View {
    @Binding var plan: ServingPlan

    var body: some View {
        Section {
            Toggle("Several portions (a container)", isOn: $plan.isContainer.animation())
            if plan.isContainer {
                Stepper(value: $plan.servings, in: 2...20) {
                    Text("Portions: \(plan.servings)")
                }
                Toggle("Eat one now", isOn: $plan.eatNow)
                Stepper(value: $plan.keepDays, in: 1...14) {
                    Text("Keeps: ^[\(plan.keepDays) day](inflect: true)")
                }
            }
        } footer: {
            if plan.isContainer {
                Text("The other portions go to \"Ready in the fridge\" on Today. Numbers above are for one portion.")
            }
        }
    }
}

/// Log a food that has nutrition per 100 g: a typical dish, a basic food or one of "My products".
struct FoodAmountView: View {
    let food: Food
    let title: String
    /// Small / medium / large makes no sense for a packaged product.
    var showsSizes = true
    let done: () -> Void

    @Environment(\.modelContext) private var context
    @State private var grams: Double
    @State private var size: PortionSize? = .medium
    @State private var plan = ServingPlan()

    init(food: Food, title: String, showsSizes: Bool = true, done: @escaping () -> Void) {
        self.food = food
        self.title = title
        self.showsSizes = showsSizes
        self.done = done
        _grams = State(initialValue: food.grams(of: .medium))
    }

    var body: some View {
        Form {
            Section("How much") {
                if showsSizes {
                    Picker("Size", selection: $size) {
                        Text("Small").tag(PortionSize?.some(.small))
                        Text("Medium").tag(PortionSize?.some(.medium))
                        Text("Large").tag(PortionSize?.some(.large))
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: size) { _, new in
                        if let new { grams = food.grams(of: new) }
                    }
                }
                if let unit = food.units.last {
                    Stepper {
                        Text(verbatim: "\(count(of: unit).formatted(.number.precision(.fractionLength(0...1)))) × \(unit.name.current)")
                    } onIncrement: {
                        setGrams((count(of: unit) + 0.5) * unit.grams)
                    } onDecrement: {
                        setGrams(max(count(of: unit) - 0.5, 0.5) * unit.grams)
                    }
                }
                Stepper(value: Binding(get: { grams }, set: { setGrams($0) }), in: 10...2000, step: 10) {
                    Text("Weight: \(Int(grams.rounded())) g")
                }
            }

            Section("This portion") {
                NutritionRows(value: food.nutrition(grams: grams))
            }

            ServingPlanSection(plan: $plan)

            Section {
                Button("Log", systemImage: "checkmark.circle") {
                    plan.log(title: title, perServing: food.nutrition(grams: grams), in: context)
                    done()
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func count(of unit: HouseholdUnit) -> Double {
        (grams / unit.grams * 2).rounded() / 2
    }

    private func setGrams(_ value: Double) {
        grams = value.rounded()
        size = PortionSize.allCases.first { food.grams(of: $0) == grams }
    }
}

/// Log food by its numbers: typed in, or pasted from Claude (prefilled).
struct ManualFoodView: View {
    let done: () -> Void

    @Environment(\.modelContext) private var context
    @State private var title: String
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var fat: Double?
    @State private var carbs: Double?
    @State private var plan = ServingPlan()

    init(prefill: ClaudeFoodCode? = nil, done: @escaping () -> Void) {
        self.done = done
        _title = State(initialValue: prefill?.title ?? "")
        _kcal = State(initialValue: prefill?.perServing.kcal)
        _protein = State(initialValue: prefill?.perServing.protein)
        _fat = State(initialValue: prefill?.perServing.fat)
        _carbs = State(initialValue: prefill?.perServing.carbs)
        if let prefill, prefill.servings > 1 {
            _plan = State(initialValue: ServingPlan(isContainer: true, servings: prefill.servings))
        }
    }

    var body: some View {
        Form {
            Section("What") {
                TextField("Name", text: $title)
            }
            Section("One portion") {
                NumberField("Calories, kcal", value: $kcal)
                NumberField("Protein, g", value: $protein)
                NumberField("Fat, g", value: $fat)
                NumberField("Carbs, g", value: $carbs)
            }
            ServingPlanSection(plan: $plan)
            Section {
                Button("Log", systemImage: "checkmark.circle") {
                    let nutrition = Nutrition(kcal: kcal ?? 0, protein: protein ?? 0, fat: fat ?? 0, carbs: carbs ?? 0)
                    let name = title.trimmingCharacters(in: .whitespaces)
                    plan.log(title: name.isEmpty ? String(localized: "Food") : name, perServing: nutrition, in: context)
                    done()
                }
                .disabled(kcal == nil)
            }
        }
        .navigationTitle("Enter numbers")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Add or edit a packaged product from its label (values per 100 g).
struct MyProductForm: View {
    var product: MyProduct?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kcal: Double?
    @State private var protein: Double?
    @State private var fat: Double?
    @State private var carbs: Double?
    @State private var packGrams: Double?

    var body: some View {
        Form {
            Section("Product") {
                TextField("Name, e.g. Greek yogurt 2%", text: $name)
                NumberField("Pack weight, g", value: $packGrams)
            }
            Section {
                NumberField("Calories, kcal", value: $kcal)
                NumberField("Protein, g", value: $protein)
                NumberField("Fat, g", value: $fat)
                NumberField("Carbs, g", value: $carbs)
            } header: {
                Text("Per 100 g, from the label")
            }
            Section {
                Button("Save") { save() }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || kcal == nil)
            }
        }
        .navigationTitle(product == nil ? "New product" : "Edit product")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let product else { return }
            name = product.name
            kcal = product.kcal
            protein = product.protein
            fat = product.fat
            carbs = product.carbs
            packGrams = product.packGrams > 0 ? product.packGrams : nil
        }
    }

    private func save() {
        let per100g = Nutrition(kcal: kcal ?? 0, protein: protein ?? 0, fat: fat ?? 0, carbs: carbs ?? 0)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let product {
            product.name = trimmed
            product.per100g = per100g
            product.packGrams = packGrams ?? 0
        } else {
            context.insert(MyProduct(name: trimmed, per100g: per100g, packGrams: packGrams ?? 0))
        }
        dismiss()
    }
}

/// A labelled decimal input.
struct NumberField: View {
    let title: LocalizedStringKey
    @Binding var value: Double?

    init(_ title: LocalizedStringKey, value: Binding<Double?>) {
        self.title = title
        _value = value
    }

    var body: some View {
        LabeledContent(title) {
            TextField(title, value: $value, format: .number, prompt: Text(verbatim: "0"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
    }
}
