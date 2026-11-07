import SwiftUI
import SwiftData

struct BudgetFormView: View {
    var budget: Budget? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]
    @Query private var budgets: [Budget]

    @State private var categoryID: UUID?
    @State private var amount = ""
    @State private var loaded = false
    @State private var saveError: String?

    private var expenseCategories: [MovementCategory] {
        categories.filter { category in
            category.kind == .expense && (categoryID == category.id || !budgets.contains { $0.categoryID == category.id && $0.id != budget?.id })
        }
    }

    private var isEditing: Bool { budget != nil }
    private var parsedAmount: Int? { Money.parse(amount) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if expenseCategories.isEmpty {
                        Text("Crea primero una categoría de gasto para poder añadir un presupuesto.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Categoría", selection: $categoryID) {
                            ForEach(expenseCategories) { category in
                                HStack(spacing: 8) {
                                    IconBadge(symbol: category.icon, colorHex: category.colorHex, size: 24)
                                    Text(category.name)
                                }
                                .tag(Optional(category.id))
                            }
                        }
                    }
                } header: {
                    Text("Categoría de gasto")
                }

                Section {
                    HStack {
                        TextField("0,00", text: $amount)
                            .keyboardType(.decimalPad)
                            .accessibilityLabel("Límite mensual")
                        Text(Money.symbol)
                            .foregroundStyle(.secondary)
                    }
                    if let cents = parsedAmount, cents <= 0 {
                        Text("El límite debe ser mayor que cero.")
                            .font(.caption)
                            .foregroundStyle(palette.negative)
                    }
                } header: {
                    Text("Límite mensual")
                } footer: {
                    Text("El progreso se calcula con los gastos de esta categoría durante el mes actual.")
                }
            }
            .navigationTitle(isEditing ? "Editar presupuesto" : "Nuevo presupuesto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Guardar" : "Crear") { save() }
                        .fontWeight(.semibold)
                        .disabled(categoryID == nil || (parsedAmount ?? 0) <= 0)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let budget {
                    categoryID = budget.categoryID
                    amount = Money.editString(budget.limitCents)
                } else {
                    categoryID = expenseCategories.first?.id
                }
            }
            .alert("No se pudo guardar", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard let categoryID, let limitCents = parsedAmount, limitCents > 0 else { return }
        if let budget {
            budget.categoryID = categoryID
            budget.limitCents = limitCents
        } else {
            context.insert(Budget(categoryID: categoryID, limitCents: limitCents))
        }
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}
