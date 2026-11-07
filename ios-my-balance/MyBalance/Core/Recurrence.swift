import Foundation
import SwiftData

enum RecurrenceCalendar {
    static func alreadyRecorded(ruleID: UUID, occurrence: Date, movements: [Movement]) -> Bool {
        movements.contains { $0.recurringRuleID == ruleID && $0.recurrenceOccurrence == occurrence }
    }

    static func nextDate(
        after current: Date,
        frequency: RecurrenceFrequency,
        anchorDate: Date,
        calendar: Calendar = .app
    ) -> Date? {
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: current)
        case .biweekly:
            return calendar.date(byAdding: .day, value: 14, to: current)
        case .monthly:
            let parts = calendar.dateComponents([.year, .month], from: current)
            guard let monthStart = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)),
                  let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart),
                  let range = calendar.range(of: .day, in: .month, for: nextMonth) else { return nil }
            let day = min(calendar.component(.day, from: anchorDate), range.count)
            return calendar.date(bySetting: .day, value: day, of: nextMonth)?.startOfDay
        case .yearly:
            let anchor = calendar.dateComponents([.month, .day], from: anchorDate)
            let year = calendar.component(.year, from: current) + 1
            guard let monthStart = calendar.date(from: DateComponents(year: year, month: anchor.month, day: 1)),
                  let range = calendar.range(of: .day, in: .month, for: monthStart) else { return nil }
            let day = min(anchor.day ?? 1, range.count)
            return calendar.date(bySetting: .day, value: day, of: monthStart)?.startOfDay
        }
    }

    static func nextAllowedDate(for rule: RecurringRule, after date: Date? = nil, calendar: Calendar = .app) -> Date? {
        guard let next = nextDate(
            after: date ?? rule.nextOccurrence,
            frequency: rule.frequency,
            anchorDate: rule.startDate,
            calendar: calendar
        ) else { return nil }
        if let endDate = rule.endDate,
           next >= calendar.startOfDay(for: endDate).addingDays(1) { return nil }
        return next
    }
}

enum BudgetAlertThreshold: Int, CaseIterable, Identifiable {
    case eighty = 80
    case oneHundred = 100
    case exceeded = 101

    var id: Int { rawValue }
    var percent: Int { self == .exceeded ? 100 : rawValue }
    var label: String { self == .exceeded ? "Al superar el presupuesto" : "Al alcanzar el \(rawValue)%" }

    static func notificationKey(categoryID: UUID, monthStart: Date, threshold: BudgetAlertThreshold, calendar: Calendar = .app) -> String {
        let parts = calendar.dateComponents([.year, .month], from: monthStart)
        let monthKey = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        return "budgetNotification.v2.fired.\(categoryID.uuidString).\(monthKey).\(threshold.rawValue)"
    }

    static func notificationRequestID(categoryID: UUID, monthStart: Date, threshold: BudgetAlertThreshold, calendar: Calendar = .app) -> String {
        let parts = calendar.dateComponents([.year, .month], from: monthStart)
        let monthKey = String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
        return "budget-\(categoryID.uuidString)-\(monthKey)-\(threshold.rawValue)"
    }

    static func crossed(spent: Int, limit: Int, enabled: Set<BudgetAlertThreshold>) -> [BudgetAlertThreshold] {
        guard limit > 0 else { return [] }
        let crossed = allCases.filter { threshold in
            guard enabled.contains(threshold) else { return false }
            if threshold == .exceeded { return spent > limit }
            return Double(spent) / Double(limit) * 100 >= Double(threshold.percent)
        }
        // If one movement crosses several levels at once, report only the highest one.
        return crossed.last.map { [$0] } ?? []
    }
}
