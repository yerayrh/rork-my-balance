import Foundation
import UserNotifications

@MainActor
enum AppNotifications {
    private static let center = UNUserNotificationCenter.current()

    static func requestPermission() async -> Bool {
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        @unknown default:
            return false
        }
    }

    static func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix("budget-") || $0.hasPrefix("recurring-") }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        center.removeDeliveredNotifications(withIdentifiers: ids)
    }

    static func refresh(
        settings: AppSettings,
        movements: [Movement],
        budgets: [Budget],
        categories: [MovementCategory],
        recurringRules: [RecurringRule]
    ) async {
        guard settings.notificationsEnabled else {
            await cancelAll()
            return
        }

        await refreshBudgetAlerts(settings: settings, movements: movements, budgets: budgets, categories: categories)
        await refreshRecurringReminders(recurringRules)
    }

    private static func refreshBudgetAlerts(
        settings: AppSettings,
        movements: [Movement],
        budgets: [Budget],
        categories: [MovementCategory]
    ) async {
        let now = Date()
        let month = Calendar.app.dateComponents([.year, .month], from: now)
        let monthKey = String(format: "%04d-%02d", month.year ?? 0, month.month ?? 0)
        let monthStart = now.startOfMonth
        let range = DateRange.month(now)
        var enabled = Set<BudgetAlertThreshold>()
        if settings.budgetAlert80 { enabled.insert(.eighty) }
        if settings.budgetAlert100 { enabled.insert(.oneHundred) }
        if settings.budgetAlertOver { enabled.insert(.exceeded) }

        for budget in budgets where budget.limitCents > 0 {
            guard let category = categories.first(where: { $0.id == budget.categoryID }), category.kind == .expense else { continue }
            let spent = Finance.spent(in: category.id, movements: movements, range: range)
            for threshold in BudgetAlertThreshold.crossed(spent: spent, limit: budget.limitCents, enabled: enabled) {
                let firedKey = BudgetAlertThreshold.notificationKey(categoryID: category.id, monthStart: monthStart, threshold: threshold)
                guard !UserDefaults.standard.bool(forKey: firedKey) else { continue }
                let content = UNMutableNotificationContent()
                content.title = "Presupuesto · \(category.name)"
                if threshold == .exceeded {
                    content.body = "Has superado el límite de \(Money.format(budget.limitCents)) este mes. Llevas \(Money.format(spent))."
                } else {
                    content.body = "Has alcanzado el \(threshold.percent)% de tu presupuesto. Llevas \(Money.format(spent)) de \(Money.format(budget.limitCents))."
                }
                content.sound = .default
                let monthKey = String(BudgetAlertThreshold.notificationKey(categoryID: category.id, monthStart: monthStart, threshold: threshold).split(separator: ".").dropFirst(2).joined(separator: "."))
                let id = "budget-\(category.id.uuidString)-\(monthKey)-\(threshold.rawValue)"
                do {
                    try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
                    UserDefaults.standard.set(true, forKey: firedKey)
                } catch {
                    // Leave the key unset so the next app refresh can retry.
                }
            }
        }
    }

    private static func refreshRecurringReminders(_ rules: [RecurringRule]) async {
        let pending = await center.pendingNotificationRequests()
        center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix("recurring-") })

        let nextRules = rules
            .filter { rule in
                rule.isActive && (rule.endDate.map { rule.nextOccurrence <= $0 } ?? true)
            }
            .sorted { $0.nextOccurrence < $1.nextOccurrence }
            .prefix(40)

        for rule in nextRules {
            let content = UNMutableNotificationContent()
            content.title = "Movimiento recurrente pendiente"
            content.body = "Revisa «\(rule.title.isEmpty ? rule.kind.label : rule.title)» por \(Money.format(rule.amountCents)) y confirma si quieres añadirlo."
            content.sound = .default
            var components = Calendar.app.dateComponents([.year, .month, .day], from: rule.nextOccurrence)
            components.hour = 9
            components.minute = 0
            let trigger: UNNotificationTrigger
            if rule.nextOccurrence <= Date() {
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            } else {
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }
            let request = UNNotificationRequest(identifier: "recurring-\(rule.id.uuidString)", content: content, trigger: trigger)
            try? await center.add(request)
        }
    }
}
