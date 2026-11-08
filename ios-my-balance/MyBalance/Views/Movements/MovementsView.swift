import SwiftUI
import SwiftData

struct MovementsTab: View {
    var body: some View {
        NavigationStack {
            MovementsView()
        }
    }
}

struct MovementsView: View {
    @Environment(\.palette) private var palette

    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]

    enum FilterKind: String, CaseIterable, Identifiable {
        case all, expense, income, transfer
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: "Todos"
            case .expense: "Gastos"
            case .income: "Ingresos"
            case .transfer: "Transferencias"
            }
        }
        var symbol: String {
            switch self {
            case .all: "tray.full"
            case .expense: "arrow.up.right"
            case .income: "arrow.down.left"
            case .transfer: "arrow.left.arrow.right"
            }
        }
    }

    @State private var filter: FilterKind = .all
    @State private var accountFilter: UUID?
    @State private var categoryFilter: UUID?
    @State private var query = ""
    @State private var showNew = false
    @State private var editing: Movement?

    private var availableCategories: [MovementCategory] {
        categories(for: filter)
    }

    private var filtered: [Movement] {
        let q = query.trimmed.lowercased()
        return movements.filter { m in
            if filter != .all {
                switch (filter, m.kind) {
                case (.expense, .expense), (.income, .income), (.transfer, .transfer):
                    break
                default:
                    return false
                }
            }
            if let accountFilter, m.accountID != accountFilter && m.toAccountID != accountFilter { return false }
            if let categoryFilter, m.categoryID != categoryFilter { return false }
            if !q.isEmpty {
                let hay = (m.title + " " + m.notes).lowercased()
                if !hay.contains(q) { return false }
            }
            return true
        }
    }

    var body: some View {
        let lookup = Lookup(accounts: accounts, categories: categories)

        Group {
            if movements.isEmpty {
                emptyState
            } else {
                list(lookup)
            }
        }
        .background(palette.canvas)
        .navigationTitle("Movimientos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nuevo movimiento")
            }
        }
        .searchable(text: $query, prompt: "Buscar en conceptos y notas")
        .sheet(isPresented: $showNew) { MovementFormView(movement: nil) }
        .sheet(item: $editing) { MovementFormView(movement: $0) }
    }

    private var emptyState: some View {
        VStack {
            EmptyCard(symbol: "tray.full", title: "Sin movimientos", message: "Aquí verás todos tus gastos, ingresos y transferencias. Crea el primero con el botón +.")
        }
        .padding(20)
    }

    private func list(_ lookup: Lookup) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                filters

                if filtered.isEmpty {
                    Text("Ningún movimiento coincide con los filtros.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                        .padding(.top, 8)
                } else {
                    summary
                    groups(lookup)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(FilterKind.allCases) { k in
                        Chip(title: k.label, symbol: k.symbol, selected: filter == k) {
                            withAnimation(.snappy(duration: 0.25)) {
                                filter = k
                                if let categoryFilter,
                                   !categories(for: k).contains(where: { $0.id == categoryFilter }) {
                                    self.categoryFilter = nil
                                }
                            }
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.horizontal, -20)

            Menu {
                Picker("Cuenta", selection: $accountFilter) {
                    Text("Todas las cuentas").tag(UUID?.none)
                    ForEach(accounts) { a in
                        Text(a.name).tag(UUID?.some(a.id))
                    }
                }
                Picker("Categoría", selection: $categoryFilter) {
                    Text("Todas las categorías").tag(UUID?.none)
                    ForEach(availableCategories) { c in
                        Text(c.name).tag(UUID?.some(c.id))
                    }
                }
                if accountFilter != nil || categoryFilter != nil {
                    Button(role: .destructive) {
                        accountFilter = nil
                        categoryFilter = nil
                    } label: {
                        Label("Quitar filtros", systemImage: "xmark.circle")
                    }
                }
            } label: {
                Label(
                    accountFilter == nil && categoryFilter == nil ? "Filtros" : "Filtros activos",
                    systemImage: accountFilter == nil && categoryFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accountFilter == nil && categoryFilter == nil ? .secondary : palette.accent)
            }
        }
    }

    private func categories(for filter: FilterKind) -> [MovementCategory] {
        switch filter {
        case .all:
            categories
        case .expense:
            categories.filter { $0.kind == .expense }
        case .income:
            categories.filter { $0.kind == .income }
        case .transfer:
            []
        }
    }

    private var summary: some View {
        let t = Finance.totals(filtered)
        return HStack(spacing: 10) {
            MetricTile(title: "Ingresos", cents: t.income, symbol: "arrow.down.left", tint: palette.positive, fillHex: "#EAFAF4")
            MetricTile(title: "Gastos", cents: t.expense, symbol: "arrow.up.right", tint: palette.negative, fillHex: "#FDEFF6")
            MetricTile(title: "Balance", cents: t.net, symbol: "equal", tint: t.net >= 0 ? palette.positive : palette.negative, sign: .always, fillHex: t.net >= 0 ? "#EAFAF4" : "#FDEFF6")
        }
    }

    private func groups(_ lookup: Lookup) -> some View {
        let grouped = Dictionary(grouping: filtered) { $0.date.startOfDay }
        let days = grouped.keys.sorted().reversed()
        return VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(days.enumerated()), id: \.element) { _, day in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(Fmt.dayHeader(day))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        Spacer()
                        let dayNet = grouped[day]!.reduce(0) { $0 + ($1.isExcluded || $1.kind == .transfer ? 0 : ($1.kind == .income ? $1.amountCents : -$1.amountCents)) }
                        Text(Money.format(dayNet, sign: .always))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        let list = grouped[day]!.sorted { $0.date > $1.date }
                        ForEach(Array(list.enumerated()), id: \.element.id) { i, m in
                            Button { editing = m } label: {
                                MovementRow(movement: m, lookup: lookup)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(PressableStyle())
                            .foregroundStyle(.primary)
                            if i < list.count - 1 {
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                    .card(padding: 14)
                }
            }
        }
    }
}
