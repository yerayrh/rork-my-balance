import SwiftUI
import SwiftData
import Charts

struct HomeView: View {
    @Environment(\.palette) private var palette
    @Environment(AppRouter.self) private var router
    @Environment(AppSettings.self) private var settings
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(\.modelContext) private var context

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]

    @State private var month = Date().startOfMonth
    @State private var showAllCategories = false
    @State private var showNewMovement = false
    @State private var showNewAccount = false
    @State private var editing: Movement?
    @State private var confirmRemoveDemo = false
    private var activeAccounts: [Account] { accounts.filter { !$0.isArchived } }

    var body: some View {
        let lookup = Lookup(accounts: accounts, categories: categories)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if accounts.contains(where: \.isDemo) { demoBanner }
                    hero
                    accountsStrip
                    monthSummary
                    topCategories(lookup)
                    recent(lookup)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .background(palette.canvas)
            .navigationTitle("Inicio")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        settings.accountBalancesVisible.toggle()
                    } label: {
                        Image(systemName: settings.accountBalancesVisible ? "eye" : "eye.slash")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(settings.accountBalancesVisible ? "Ocultar saldos de cuentas" : "Mostrar saldos de cuentas")
                    .accessibilityHint("Oculta o muestra el total y los saldos de tus cuentas en la app")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .overlay(alignment: .bottomTrailing) {
                FloatingAddButton { showNewMovement = true }
                    .padding(.trailing, 20)
                    .padding(.bottom, 16)
            }
            .sheet(isPresented: $showNewMovement) { MovementFormView(movement: nil) }
            .sheet(isPresented: $showNewAccount) { AccountFormView(account: nil) }
            .sheet(item: $editing) { MovementFormView(movement: $0) }
        }
    }

    // MARK: Demo banner

    private var demoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(palette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Estás viendo datos de ejemplo")
                    .font(.subheadline.weight(.semibold))
                Text("No son datos reales.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Eliminar") { confirmRemoveDemo = true }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .confirmationDialog("¿Eliminar los datos de demostración?", isPresented: $confirmRemoveDemo, titleVisibility: .visible) {
                    Button("Eliminar datos de demostración", role: .destructive) {
                        withAnimation {
                            do { try Seed.removeDemo(context) }
                            catch { errorCenter.message = error.localizedDescription }
                        }
                    }
                } message: {
                    Text("Se borrarán las cuentas, movimientos y presupuestos de ejemplo. Tus datos reales no se tocan.")
                }
        }
        .card(padding: 14)
    }

    // MARK: Hero — total money

    private var hero: some View {
        let total = Finance.total(activeAccounts, movements)
        let change = Finance.monthChange(activeAccounts, movements)
        let earliest = activeAccounts.map { $0.initialDate.startOfDay }.min() ?? .now
        let from = max(earliest, Date().startOfMonth.addingMonths(-5))
        let series = Finance.patrimonySeries(activeAccounts, movements, from: from)

        return VStack(alignment: .leading, spacing: 8) {
            if !settings.userName.trimmed.isEmpty {
                Text("Hola, \(settings.userName.trimmed)")
                    .font(.title3.weight(.semibold))
            }
            Text("Dinero total")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(settings.accountBalancesVisible ? Money.format(total) : Money.masked)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText())
                .animation(.snappy, value: total)
                .accessibilityLabel(settings.accountBalancesVisible ? Money.format(total) : "Saldo total oculto")

            if settings.accountBalancesVisible {
                if let change {
                    let up = change.delta >= 0
                    HStack(spacing: 6) {
                        Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.weight(.bold))
                        Text(change.percent.map { Fmt.percent($0, sign: true) } ?? Money.format(change.delta, sign: .always))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                        Text("vs. mes anterior")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(up ? palette.positive : palette.negative)
                } else if !activeAccounts.isEmpty {
                    Text("Aún no hay datos del mes anterior")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if series.count > 1 {
                    patrimonyChart(series)
                        .frame(height: 190)
                        .padding(.top, 10)
                }
            }

        }
    }

    private func patrimonyChart(_ series: [BalancePoint]) -> some View {
        let values = series.map(\.amount)
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let pad = max((maxV - minV) * 0.15, 1)
        let spanDays = (series.last?.date.timeIntervalSince(series.first?.date ?? .now) ?? 0) / 86_400
        return Chart(series) { p in
            AreaMark(
                x: .value("Fecha", p.date),
                yStart: .value("Base", minV - pad),
                yEnd: .value("Saldo", p.amount)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(LinearGradient(colors: [palette.accent.opacity(0.28), palette.accent.opacity(0.0)], startPoint: .top, endPoint: .bottom))
            LineMark(x: .value("Fecha", p.date), y: .value("Saldo", p.amount))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundStyle(palette.accent)
            if let last = series.last, p.id == last.id {
                PointMark(x: .value("Fecha", p.date), y: .value("Saldo", p.amount))
                    .symbol {
                        Circle()
                            .fill(palette.accent)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(palette.surface, lineWidth: 2.5))
                            .shadow(color: palette.accent.opacity(0.45), radius: 4)
                    }
            }
        }
        .chartYScale(domain: (minV - pad)...(maxV + pad))
        .chartPlotStyle { plot in
            plot.padding(.trailing, 10)
        }
        .chartXAxis {
            if spanDays > 60 {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: false)
                        .font(.caption2)
                }
            } else {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        .font(.caption2)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                    .foregroundStyle(Color.primary.opacity(0.12))
                AxisValueLabel(horizontalSpacing: 10) {
                    if let d = value.as(Double.self) {
                        Text("\(Money.compact(d)) \(Money.symbol)")
                            .font(.caption2)
                            .monospacedDigit()
                    }
                }
            }
        }
        .environment(\.locale, Fmt.es)
        .accessibilityLabel("Evolución del dinero total")
    }

    // MARK: Accounts strip

    private var accountsStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cuentas", actionTitle: accounts.isEmpty ? nil : "Ver todas") {
                router.tab = .accounts
            }
            if accounts.isEmpty {
                EmptyCard(symbol: "building.columns.fill", title: "Crea tu primera cuenta", message: "Añade tus bancos, tarjetas o efectivo para empezar a controlar tu dinero.", actionTitle: "Añadir cuenta") {
                    showNewAccount = true
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(activeAccounts) { a in
                            NavigationLink {
                                AccountDetailView(account: a)
                            } label: {
                                AccountCard(
                                    account: a,
                                    balance: Finance.balance(of: a, in: movements),
                                    hideBalance: !settings.accountBalancesVisible
                                )
                            }
                            .buttonStyle(PressableStyle())
                            .disabled(!settings.accountBalancesVisible)
                        }
                        Button { showNewAccount = true } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title2.weight(.bold))
                                Text("Añadir")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(palette.accent)
                            .frame(width: 100, height: 132)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .padding(.horizontal, -20)
            }
        }
    }

    // MARK: Month summary

    private var monthSummary: some View {
        let totals = Finance.totals(Finance.statMovements(movements, range: .month(month)))
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Resumen mensual")
            MonthSelector(month: $month)
            HStack(spacing: 10) {
                MetricTile(title: "Ingresos", cents: totals.income, symbol: "arrow.down.left", tint: palette.positive, fillHex: "#EAFAF4")
                MetricTile(title: "Gastos", cents: totals.expense, symbol: "arrow.up.right", tint: palette.negative, fillHex: "#FDEFF6")
                MetricTile(title: "Balance", cents: totals.net, symbol: "equal", tint: totals.net >= 0 ? palette.positive : palette.negative, sign: .always, fillHex: totals.net >= 0 ? "#EAFAF4" : "#FDEFF6")
            }
        }
    }

    // MARK: Top categories

    private func topCategories(_ lookup: Lookup) -> some View {
        let monthMovements = Finance.statMovements(movements, range: .month(month))
        let slices = Finance.breakdown(monthMovements, kind: .expense, lookup: lookup)
        let total = slices.reduce(0) { $0 + $1.cents }
        let visible = showAllCategories ? slices : Array(slices.prefix(5))

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Principales gastos")
            if slices.isEmpty {
                Text("No hay gastos en \(Fmt.monthYear(month).lowercased()).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                VStack(spacing: 16) {
                    HStack(spacing: 18) {
                        ZStack {
                            Chart(slices) { s in
                                SectorMark(angle: .value("Importe", s.amount), innerRadius: .ratio(0.64), angularInset: 1.5)
                                    .cornerRadius(4)
                                    .foregroundStyle(Color(hex: s.colorHex))
                            }
                            .chartLegend(.hidden)
                            VStack(spacing: 0) {
                                Text("Gastado")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(Money.format(total))
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(width: 74)
                        }
                        .frame(width: 124, height: 124)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(slices.prefix(4)) { s in
                                HStack(spacing: 8) {
                                    Circle().fill(Color(hex: s.colorHex)).frame(width: 9, height: 9)
                                    Text(s.name).font(.caption.weight(.medium)).lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(Fmt.percent(s.share, decimals: 0))
                                        .font(.caption.weight(.semibold))
                                        .monospacedDigit()
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Divider()

                    VStack(spacing: 14) {
                        ForEach(visible) { s in
                            VStack(spacing: 6) {
                                HStack(spacing: 10) {
                                    IconBadge(symbol: s.icon, colorHex: s.colorHex, size: 32)
                                    Text(s.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 0) {
                                        Text(Money.format(s.cents))
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                            .monospacedDigit()
                                        Text(Fmt.percent(s.share))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                GeometryReader { geo in
                                    Capsule().fill(Color.primary.opacity(0.07))
                                        .overlay(alignment: .leading) {
                                            Capsule().fill(Color(hex: s.colorHex))
                                                .frame(width: max(6, geo.size.width * s.share))
                                        }
                                }
                                .frame(height: 6)
                            }
                        }
                    }

                    if slices.count > 5 {
                        Button {
                            withAnimation(.snappy) { showAllCategories.toggle() }
                        } label: {
                            Text(showAllCategories ? "Mostrar menos" : "Ver todas (\(slices.count))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.accent)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .card()
            }
        }
    }

    // MARK: Recent movements

    private func recent(_ lookup: Lookup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Últimos movimientos", actionTitle: movements.isEmpty ? nil : "Ver todos") {
                router.tab = .movements
            }
            if movements.isEmpty {
                Text(accounts.isEmpty ? "Crea una cuenta y registra tu primer movimiento con el botón +." : "Aún no hay movimientos. Pulsa + para registrar el primero.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(movements.prefix(6).enumerated()), id: \.element.id) { index, m in
                        Button { editing = m } label: {
                            MovementRow(movement: m, lookup: lookup)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(PressableStyle())
                        .foregroundStyle(.primary)
                        if index < min(movements.count, 6) - 1 {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
                .card(padding: 14)
            }
        }
    }
}
