import SwiftUI
import SwiftData

struct CategoryMovementsView: View {
    let category: MovementCategory

    @Environment(\.palette) private var palette
    @Query(sort: \Movement.date, order: .reverse) private var allMovements: [Movement]
    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]

    @State private var editing: Movement?

    private var movements: [Movement] {
        allMovements.filter { $0.categoryID == category.id }
    }

    var body: some View {
        let lookup = Lookup(accounts: accounts, categories: categories)
        let totals = Finance.totals(movements)
        let total = category.kind == .expense ? totals.expense : totals.income
        let title = category.kind == .expense ? "Gastos" : "Ingresos"
        let tint = category.kind == .expense ? palette.negative : palette.positive

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    IconBadge(symbol: category.icon, colorHex: category.colorHex, size: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.name)
                            .font(.title3.weight(.bold))
                        Text("\(movements.count) \(movements.count == 1 ? "movimiento" : "movimientos")")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .card()

                MetricTile(
                    title: "\(title) registrados",
                    cents: total,
                    symbol: category.kind == .expense ? "arrow.up.right" : "arrow.down.left",
                    tint: tint
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "Todos los movimientos")
                    if movements.isEmpty {
                        Text("Todavía no hay movimientos en esta categoría.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                    } else {
                        let grouped = Dictionary(grouping: movements) { $0.date.startOfDay }
                        let days = grouped.keys.sorted().reversed()
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Array(days.enumerated()), id: \.element) { _, day in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(Fmt.dayHeader(day))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 4)
                                    ForEach(grouped[day]!.sorted { $0.date > $1.date }) { movement in
                                        Button { editing = movement } label: {
                                            MovementRow(movement: movement, lookup: lookup, showDate: false)
                                                .padding(.vertical, 8)
                                        }
                                        .buttonStyle(PressableStyle())
                                        .foregroundStyle(.primary)
                                        Divider().padding(.leading, 54)
                                    }
                                }
                            }
                        }
                        .card(padding: 16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(palette.canvas)
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { MovementFormView(movement: $0) }
    }
}
