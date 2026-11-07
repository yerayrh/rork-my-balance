import SwiftUI
import SwiftData
import Charts

struct BudgetsTab: View {
    var body: some View {
        NavigationStack {
            BudgetsView()
        }
    }
}

struct BudgetsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(AppErrorCenter.self) private var errorCenter

    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]
    @Query private var budgets: [Budget]

    @State private var showingBudgetForm = false
    @State private var budgetToEdit: Budget?

    private var monthRange: DateRange { DateRange.month(.now) }
    private var visibleBudgets: [Budget] {
        budgets
            .filter { budget in categories.contains(where: { $0.id == budget.categoryID }) }
            .sorted { sortOrder(for: $0.categoryID) < sortOrder(for: $1.categoryID) }
    }
    private var budgetedCategoryIDs: Set<UUID> { Set(budgets.map(\.categoryID)) }
    private var canAddBudget: Bool {
        categories.contains { $0.kind == .expense && !budgetedCategoryIDs.contains($0.id) }
    }
    private var rows: [BudgetRow] {
        visibleBudgets.compactMap { budget in
            guard let category = categories.first(where: { $0.id == budget.categoryID }) else { return nil }
            return BudgetRow(
                budget: budget,
                category: category,
                spent: Finance.spent(in: category.id, movements: movements, range: monthRange)
            )
        }
    }
    private var totalSpent: Int { rows.reduce(0) { $0 + $1.spent } }
    private var totalLimit: Int { rows.reduce(0) { $0 + $1.budget.limitCents } }
    private var totalOverage: Int { rows.reduce(0) { $0 + max(0, $1.spent - $1.budget.limitCents) } }
    private var exceededCount: Int { rows.filter { $0.spent > $0.budget.limitCents }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                monthSummary
                budgetList
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(palette.canvas)
        .navigationTitle("Presupuestos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    budgetToEdit = nil
                    showingBudgetForm = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .disabled(!canAddBudget)
                .accessibilityLabel("Añadir presupuesto")
            }
        }
        .sheet(isPresented: $showingBudgetForm, onDismiss: { budgetToEdit = nil }) {
            BudgetFormView(budget: budgetToEdit)
        }
    }

    private var monthSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(Fmt.monthYear(.now).capitalized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            if rows.isEmpty {
                HStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(palette.accent)
                        .frame(width: 72, height: 72)
                        .background(palette.accent.opacity(0.10), in: Circle())
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Aún no hay presupuestos")
                            .font(.headline)
                        Text("Añade límites mensuales y aquí verás cuánto has gastado.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 18) {
                    ZStack {
                        Chart(chartSlices) { slice in
                            SectorMark(
                                angle: .value("Importe", max(1, slice.cents)),
                                innerRadius: .ratio(0.72),
                                angularInset: 2
                            )
                            .foregroundStyle(slice.color)
                            .cornerRadius(4)
                        }
                        .chartLegend(.hidden)
                        .frame(width: 116, height: 116)

                        VStack(spacing: 2) {
                            Text(Money.format(totalSpent))
                                .font(.system(.headline, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            Text("gastado")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 78)
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Gasto del mes")
                            .font(.subheadline.weight(.semibold))
                        Text("de \(Money.format(totalLimit)) presupuestados")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if exceededCount > 0 {
                            Text("Excedido en \(exceededCount) \(exceededCount == 1 ? "categoría" : "categorías") · \(Money.format(totalOverage))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(palette.negative)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            Text("Dentro del límite en todas las categorías")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(palette.positive)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 16)
    }

    private var budgetList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Presupuestos del mes",
                actionTitle: canAddBudget ? "Añadir" : nil,
                action: {
                    budgetToEdit = nil
                    showingBudgetForm = true
                }
            )

            if rows.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Crea un presupuesto para una categoría de gasto y controla su progreso mes a mes.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        budgetToEdit = nil
                        showingBudgetForm = true
                    } label: {
                        Label("Crear presupuesto", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .disabled(!canAddBudget)
                    if !canAddBudget {
                        Text("No hay categorías de gasto disponibles para presupuestar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            } else {
                VStack(spacing: 18) {
                    ForEach(rows) { row in
                        budgetRow(row)
                    }
                }
                .padding(16)
                .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }

    private func budgetRow(_ row: BudgetRow) -> some View {
        let limit = row.budget.limitCents
        let ratio = limit > 0 ? Double(row.spent) / Double(limit) : 0
        let exceeded = row.spent > limit
        let fill = exceeded ? palette.negative : Color(hex: row.category.colorHex)

        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                IconBadge(symbol: row.category.icon, colorHex: row.category.colorHex, size: 34)
                Button {
                    budgetToEdit = row.budget
                    showingBudgetForm = true
                } label: {
                    HStack(spacing: 8) {
                        Text(row.category.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(Money.format(row.spent))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(exceeded ? palette.negative : .primary)
                            Text("de \(Money.format(limit))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Editar presupuesto de \(row.category.name)")

                Menu {
                    Button {
                        budgetToEdit = row.budget
                        showingBudgetForm = true
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        context.delete(row.budget)
                        do { try context.save() }
                        catch {
                            context.rollback()
                            errorCenter.message = error.localizedDescription
                        }
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 34)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Opciones de presupuesto de \(row.category.name)")
            }

            GeometryReader { geometry in
                Capsule()
                    .fill(Color.primary.opacity(0.07))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(fill)
                            .frame(width: row.spent == 0 ? 0 : max(6, geometry.size.width * min(1, ratio)))
                    }
            }
            .frame(height: 5)
            .accessibilityLabel("\(Int(ratio * 100)) por ciento del presupuesto usado")
        }
    }

    private var chartSlices: [BudgetChartSlice] {
        var slices: [BudgetChartSlice] = []
        let used = rows.reduce(0) { $0 + min($1.spent, $1.budget.limitCents) }
        let remaining = rows.reduce(0) { $0 + max(0, $1.budget.limitCents - $1.spent) }
        if used > 0 { slices.append(BudgetChartSlice(id: "used", cents: used, color: palette.accent)) }
        if remaining > 0 { slices.append(BudgetChartSlice(id: "remaining", cents: remaining, color: palette.accent.opacity(0.16))) }
        if totalOverage > 0 { slices.append(BudgetChartSlice(id: "over", cents: totalOverage, color: palette.negative)) }
        if slices.isEmpty { slices.append(BudgetChartSlice(id: "empty", cents: 1, color: palette.accent.opacity(0.16))) }
        return slices
    }

    private func sortOrder(for categoryID: UUID) -> Int {
        categories.first(where: { $0.id == categoryID })?.sortOrder ?? Int.max
    }
}

private struct BudgetRow: Identifiable {
    let budget: Budget
    let category: MovementCategory
    let spent: Int
    var id: UUID { budget.id }
}

private struct BudgetChartSlice: Identifiable {
    let id: String
    let cents: Int
    let color: Color
}
