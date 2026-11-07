import AppIntents
import SwiftUI
import WidgetKit

private let widgetAppGroup = "group.app.rork.az5buhimhitjfrma56m6x"
private let widgetSnapshotKey = "myBalance.widget.snapshot.v1"

private struct SharedBudgetSnapshot: Decodable {
    struct Category: Decodable, Identifiable {
        let id: String
        let name: String
        let colorHex: String
        let spentCents: Int
    }

    let monthLabel: String
    let currencySymbol: String
    let spentCents: Int
    let budgetCents: Int
    let remainingCents: Int
    let categories: [Category]
    let isVisible: Bool
    let updatedAt: Date
}

private struct BudgetWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedBudgetSnapshot?
}

private struct BudgetWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetWidgetEntry {
        BudgetWidgetEntry(date: .now, snapshot: SharedBudgetSnapshot(
            monthLabel: "Junio 2026", currencySymbol: "€", spentCents: 123_45, budgetCents: 500_00,
            remainingCents: 376_55,
            categories: [.init(id: "food", name: "Alimentación", colorHex: "#19C37D", spentCents: 73_20)],
            isVisible: true, updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetWidgetEntry) -> Void) {
        completion(BudgetWidgetEntry(date: .now, snapshot: Self.loadSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetWidgetEntry>) -> Void) {
        let entry = BudgetWidgetEntry(date: .now, snapshot: Self.loadSnapshot())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private static func loadSnapshot() -> SharedBudgetSnapshot? {
        guard let data = UserDefaults(suiteName: widgetAppGroup)?.data(forKey: widgetSnapshotKey) else { return nil }
        return try? JSONDecoder().decode(SharedBudgetSnapshot.self, from: data)
    }
}

private struct BudgetWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BudgetWidgetEntry

    var body: some View {
        Button(intent: OpenBudgetsIntent()) {
            Group {
                if let snapshot = entry.snapshot, snapshot.isVisible {
                    if family == .systemMedium {
                        medium(snapshot)
                    } else {
                        small(snapshot)
                    }
                } else {
                    hiddenContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func small(_ snapshot: SharedBudgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snapshot.monthLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("Gastado")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(amount(snapshot.spentCents, symbol: snapshot.currencySymbol))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(remainingLabel(snapshot))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .privacySensitive()
    }

    private func medium(_ snapshot: SharedBudgetSnapshot) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.monthLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("Gastado")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(amount(snapshot.spentCents, symbol: snapshot.currencySymbol))
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                Text(remainingLabel(snapshot))
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(snapshot.categories) { category in
                    HStack(spacing: 7) {
                        Circle().fill(color(category.colorHex)).frame(width: 7, height: 7)
                        Text(category.name)
                            .font(.caption2.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(amount(category.spentCents, symbol: snapshot.currencySymbol))
                            .font(.caption2.weight(.semibold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .privacySensitive()
    }

    private var hiddenContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "eye.slash.fill")
                .font(.title3)
            Text("Datos del widget ocultos")
                .font(.caption.weight(.semibold))
            Text("Puedes mostrarlos desde Ajustes en My Balance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func amount(_ cents: Int, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let value = formatter.string(from: NSNumber(value: Double(cents) / 100)) ?? "0,00"
        return "\(value) \(symbol)"
    }

    private func remainingLabel(_ snapshot: SharedBudgetSnapshot) -> String {
        if snapshot.remainingCents < 0 {
            return "Exceso \(amount(-snapshot.remainingCents, symbol: snapshot.currencySymbol))"
        }
        return "Quedan \(amount(snapshot.remainingCents, symbol: snapshot.currencySymbol))"
    }

    private func color(_ hex: String) -> Color {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x94A3B8
        return Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255, opacity: 1)
    }
}

struct BudgetSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MyBalanceBudgetWidget", provider: BudgetWidgetProvider()) { entry in
            BudgetWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Presupuesto mensual")
        .description("Consulta tus gastos y el presupuesto restante del mes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuickAddExpenseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MyBalanceQuickAddWidget", provider: BudgetWidgetProvider()) { _ in
            Button(intent: QuickAddExpenseIntent()) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30, weight: .semibold))
                    Text("Añadir gasto")
                        .font(.headline)
                    Text("Abre el formulario de My Balance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Añadir gasto")
        .description("Abre directamente el formulario para registrar un gasto.")
        .supportedFamilies([.systemSmall])
    }
}

struct QuickAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir gasto en My Balance"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: widgetAppGroup)?.set(true, forKey: "myBalance.widget.quickAddExpense")
        return .result()
    }
}

struct OpenBudgetsIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir presupuestos de My Balance"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        UserDefaults(suiteName: widgetAppGroup)?.set(true, forKey: "myBalance.widget.openBudgets")
        return .result()
    }
}

@main
struct MyBalanceWidgetBundle: WidgetBundle {
    var body: some Widget {
        BudgetSummaryWidget()
        QuickAddExpenseWidget()
    }
}
