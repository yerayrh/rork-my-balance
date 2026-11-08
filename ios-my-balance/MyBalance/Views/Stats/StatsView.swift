import SwiftUI
import SwiftData
import Charts

struct StatsTab: View {
    var body: some View {
        NavigationStack {
            StatsView()
        }
    }
}

struct StatsView: View {
    @Environment(\.palette) private var palette
    @Environment(AppRouter.self) private var router

    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]

    @State private var period: StatsPeriod = .last6
    @State private var customStart = Date().addingMonths(-2)
    @State private var customEnd = Date()

    private var range: DateRange {
        period.range(customStart: customStart, customEnd: customEnd)
    }

    var body: some View {
        let lookup = Lookup(accounts: accounts, categories: categories)
        let inRange = Finance.statMovements(movements, range: range)
        let totals = Finance.totals(inRange)
        let prevRange = period.previous(of: range)
        let prevTotals = Finance.totals(Finance.statMovements(movements, range: prevRange))
        let expenses = Finance.breakdown(inRange, kind: .expense, lookup: lookup)
        let incomes = Finance.breakdown(inRange, kind: .income, lookup: lookup)
        let chartMonthCount = range.monthStarts.count
        let chartUnit = chartMonthCount <= 6 ? "mes" : (chartMonthCount <= 24 ? "trimestre" : "año")
        let chartBars = makeChartBars(for: range)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                periodPicker

                if period == .custom {
                    HStack {
                        DatePicker("Desde", selection: $customStart, displayedComponents: .date)
                        DatePicker("Hasta", selection: $customEnd, in: customStart..., displayedComponents: .date)
                    }
                    .font(.subheadline)
                    .card(padding: 14)
                }

                if accounts.isEmpty || (inRange.isEmpty && prevTotals.net == 0) {
                    EmptyCard(
                        symbol: "chart.pie.fill",
                        title: "Todavía no hay datos",
                        message: "Cuando registres movimientos verás aquí la evolución de tus ingresos y gastos.",
                        actionTitle: accounts.isEmpty ? "Crear una cuenta" : nil
                    ) {
                        router.tab = .accounts
                    }
                } else {
                    totalsHeader(totals, prev: prevTotals)
                    monthlyChart(chartBars, unit: chartUnit)
                    breakdownSection("Gastos por categoría", symbol: "arrow.up.right", slices: expenses, total: totals.expense, tint: palette.negative, lookup: lookup)
                    breakdownSection("Ingresos por categoría", symbol: "arrow.down.left", slices: incomes, total: totals.income, tint: palette.positive, lookup: lookup)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(palette.canvas)
        .navigationTitle("Estadísticas")
    }

    private var periodPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(StatsPeriod.allCases.filter { $0 != .custom }) { p in
                    Chip(title: p.label, selected: period == p) {
                        withAnimation(.snappy(duration: 0.25)) { period = p }
                    }
                }
                Chip(title: "Personalizado", symbol: "calendar", selected: period == .custom) {
                    withAnimation(.snappy(duration: 0.25)) { period = .custom }
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .padding(.horizontal, -20)
        .sensoryFeedback(.selection, trigger: period)
    }

    private func totalsHeader(_ totals: Totals, prev: Totals) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(rangeLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            let net = totals.net
            let delta = net - prev.net
            VStack(alignment: .leading, spacing: 4) {
                Text("Balance del periodo")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(Money.format(net, sign: .always))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                if prev.income + prev.expense > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption.weight(.bold))
                        Text(Money.format(delta, sign: .always))
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                        Text("frente al periodo anterior")
                            .font(.caption)
                    }
                    .foregroundStyle(delta >= 0 ? palette.positive : palette.negative)
                }
            }

            HStack(spacing: 10) {
                MetricTile(title: "Ingresos", cents: totals.income, symbol: "arrow.down.left", tint: palette.positive, footnote: prevDelta(prev.income, totals.income))
                MetricTile(title: "Gastos", cents: totals.expense, symbol: "arrow.up.right", tint: palette.negative, footnote: prevDelta(prev.expense, totals.expense))
            }
        }
        .card()
    }

    private func prevDelta(_ before: Int, _ now: Int) -> String? {
        guard before > 0 else { return nil }
        let pct = Double(now - before) / Double(before)
        return (pct >= 0 ? "▲ " : "▼ ") + Fmt.percent(abs(pct), decimals: 0) + " vs. anterior"
    }

    private var rangeLabel: String {
        if range.monthStarts.count == 1 || period == .thisMonth || period == .lastMonth {
            return Fmt.monthYear(range.start)
        }
        return "\(Fmt.date(range.start)) – \(Fmt.date(range.end.addingDays(-1)))"
    }

    private func monthlyChart(_ bars: [MonthlyBar], unit: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingresos y gastos por \(unit)")
                .font(.headline)
            if bars.count < 2 {
                Text("Se necesitan al menos dos periodos para mostrar la gráfica.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let points = chartPoints(bars)
                let many = bars.count > 6
                Chart(points) { p in
                    BarMark(
                        x: .value("Mes", p.label),
                        y: .value("Importe", p.value),
                        width: .ratio(many ? 0.8 : 0.7)
                    )
                    .position(by: .value("Tipo", p.kind))
                    .foregroundStyle(by: .value("Tipo", p.kind))
                    .cornerRadius(many ? 3 : 6)
                }
                .chartForegroundStyleScale([
                    "Ingresos": palette.positive,
                    "Gastos": palette.negative
                ])
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                            .foregroundStyle(Color.primary.opacity(0.12))
                        AxisValueLabel {
                            if let d = value.as(Double.self) {
                                Text("\(Money.compact(d)) \(Money.symbol)")
                                    .font(.caption2)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
                .chartPlotStyle { plot in
                    plot.padding(.horizontal, 4)
                }
                .frame(height: 230)
                .padding(.top, 4)
                .accessibilityLabel("Comparativa de ingresos y gastos por \(unit)")

                HStack(spacing: 16) {
                    legendDot(palette.positive, "Ingresos")
                    legendDot(palette.negative, "Gastos")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .card()
    }

    private func legendDot(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }

    private func monthShort(_ d: Date) -> String {
        let s = Fmt.monthYear(d)
        return String(s.split(separator: " ").first?.prefix(3) ?? "")
    }

    private func makeChartBars(for range: DateRange) -> [MonthlyBar] {
        let months = range.monthStarts.map { month -> MonthlyBar in
            let clippedRange = DateRange(
                start: max(month, range.start),
                end: min(month.addingMonths(1), range.end)
            )
            let totals = Finance.totals(Finance.statMovements(movements, range: clippedRange))
            return MonthlyBar(month: month, label: "", income: totals.income, expense: totals.expense)
        }

        if months.count <= 6 {
            let years = Set(months.map { Calendar.app.component(.year, from: $0.month) })
            return months.map { bar in
                let year = Calendar.app.component(.year, from: bar.month)
                let label = years.count > 1 ? "\(monthShort(bar.month)) \(String(format: "%02d", year % 100))" : monthShort(bar.month)
                return MonthlyBar(month: bar.month, label: label, income: bar.income, expense: bar.expense)
            }
        }

        if months.count <= 24 {
            let groups = Dictionary(grouping: months) { bar -> String in
                let year = Calendar.app.component(.year, from: bar.month)
                let month = Calendar.app.component(.month, from: bar.month)
                let quarter = (month - 1) / 3 + 1
                return "\(year)-\(quarter)"
            }
            return groups.values.map { group in
                let first = group[0]
                let year = Calendar.app.component(.year, from: first.month)
                let month = Calendar.app.component(.month, from: first.month)
                let quarter = (month - 1) / 3 + 1
                return MonthlyBar(
                    month: first.month,
                    label: "T\(quarter) \(year)",
                    income: group.reduce(0) { $0 + $1.income },
                    expense: group.reduce(0) { $0 + $1.expense }
                )
            }
            .sorted { $0.month < $1.month }
        }

        let groups = Dictionary(grouping: months) { Calendar.app.component(.year, from: $0.month) }
        return groups.map { year, group in
            MonthlyBar(
                month: group[0].month,
                label: String(year),
                income: group.reduce(0) { $0 + $1.income },
                expense: group.reduce(0) { $0 + $1.expense }
            )
        }
        .sorted { $0.month < $1.month }
    }

    private struct ChartPoint: Identifiable {
        let id: String
        let label: String
        let kind: String
        let value: Double
    }

    private func chartPoints(_ bars: [MonthlyBar]) -> [ChartPoint] {
        return bars.flatMap { bar -> [ChartPoint] in
            return [
                ChartPoint(id: bar.label + "-i", label: bar.label, kind: "Ingresos", value: Double(bar.income) / 100),
                ChartPoint(id: bar.label + "-g", label: bar.label, kind: "Gastos", value: Double(bar.expense) / 100)
            ]
        }
    }

    private func breakdownSection(_ title: String, symbol: String, slices: [CategorySlice], total: Int, tint: Color, lookup: Lookup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title)
            if slices.isEmpty {
                Text("Sin datos en este periodo.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                VStack(spacing: 16) {
                    VStack(spacing: 16) {
                        ZStack {
                            Chart(slices.prefix(8)) { s in
                                SectorMark(angle: .value("Importe", s.amount), innerRadius: .ratio(0.64), angularInset: 1.5)
                                    .cornerRadius(4)
                                    .foregroundStyle(Color(hex: s.colorHex))
                            }
                            .chartLegend(.hidden)
                            VStack(spacing: 0) {
                                Text("Total")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(Money.format(total))
                                    .font(.system(.headline, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                            .frame(width: 104)
                        }
                        .frame(width: 176, height: 176)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 8) {
                            ForEach(slices.prefix(6)) { s in
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
                        ForEach(slices.prefix(8)) { s in
                            breakdownRow(s, lookup: lookup)
                        }
                    }
                }
                .card()
            }
        }
    }

    @ViewBuilder
    private func breakdownRow(_ slice: CategorySlice, lookup: Lookup) -> some View {
        if let category = lookup.category(slice.categoryID) {
            NavigationLink {
                CategoryMovementsView(category: category)
            } label: {
                breakdownRowContent(slice)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Muestra todos los movimientos de esta categoría")
        } else {
            breakdownRowContent(slice)
        }
    }

    private func breakdownRowContent(_ slice: CategorySlice) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                IconBadge(symbol: slice.icon, colorHex: slice.colorHex, size: 32)
                Text(slice.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(Money.format(slice.cents))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                    Text(Fmt.percent(slice.share))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            GeometryReader { geo in
                Capsule().fill(Color.primary.opacity(0.07))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color(hex: slice.colorHex))
                            .frame(width: max(6, geo.size.width * slice.share))
                    }
            }
            .frame(height: 6)
        }
        .contentShape(Rectangle())
    }

}

private struct MonthlyBar: Identifiable {
    let month: Date
    let label: String
    let income: Int
    let expense: Int
    var id: Date { month }
}
