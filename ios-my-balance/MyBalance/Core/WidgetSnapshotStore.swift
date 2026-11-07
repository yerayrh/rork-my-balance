import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let appGroupID = "group.app.rork.az5buhimhitjfrma56m6x"
    static let snapshotKey = "myBalance.widget.snapshot.v1"
    static let quickAddKey = "myBalance.widget.quickAddExpense"
    static let openBudgetsKey = "myBalance.widget.openBudgets"
    static let budgetWidgetKind = "MyBalanceBudgetWidget"
    static let quickAddWidgetKind = "MyBalanceQuickAddWidget"

    struct Snapshot: Codable {
        struct Category: Codable, Identifiable {
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

    static func publish(movements: [Movement], budgets: [Budget], categories: [MovementCategory], isVisible: Bool) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        let range = DateRange.month(.now)
        let expenseCategories = Dictionary(uniqueKeysWithValues: categories.filter { $0.kind == .expense }.map { ($0.id, $0) })
        let rows = categories.compactMap { category -> Snapshot.Category? in
            guard category.kind == .expense else { return nil }
            let spent = Finance.spent(in: category.id, movements: movements, range: range)
            guard spent > 0 else { return nil }
            return Snapshot.Category(
                id: category.id.uuidString,
                name: category.name,
                colorHex: category.colorHex,
                spentCents: spent
            )
        }.sorted { $0.spentCents > $1.spentCents }
        let totalSpent = Finance.statMovements(movements, range: range)
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amountCents }
        let totalBudget = budgets.filter { expenseCategories[$0.categoryID] != nil }.reduce(0) { $0 + $1.limitCents }
        let budgetedSpent = budgets.reduce(0) { total, budget in
            total + Finance.spent(in: budget.categoryID, movements: movements, range: range)
        }
        let snapshot = Snapshot(
            monthLabel: Fmt.monthYear(.now).capitalized,
            currencySymbol: Money.symbol,
            spentCents: totalSpent,
            budgetCents: totalBudget,
            remainingCents: totalBudget - budgetedSpent,
            categories: Array(rows.prefix(3)),
            isVisible: isVisible,
            updatedAt: .now
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadTimelines(ofKind: budgetWidgetKind)
    }
}
