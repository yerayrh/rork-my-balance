import Foundation
import SwiftData
import Testing
@testable import MyBalance

@MainActor
struct MyBalanceTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func monthlyRecurrenceClampsShortMonthsAndReturnsToAnchorDay() throws {
        let jan31 = date(2025, 1, 31)
        let february = try #require(RecurrenceCalendar.nextDate(after: jan31, frequency: .monthly, anchorDate: jan31, calendar: utcCalendar))
        #expect(utcCalendar.component(.day, from: february) == 28)
        let march = try #require(RecurrenceCalendar.nextDate(after: february, frequency: .monthly, anchorDate: jan31, calendar: utcCalendar))
        #expect(utcCalendar.component(.day, from: march) == 31)
    }

    @Test func recurrenceSupportsWeeklyBiweeklyAndLeapYearClamping() throws {
        let start = date(2024, 2, 29)
        let weekly = try #require(RecurrenceCalendar.nextDate(after: start, frequency: .weekly, anchorDate: start, calendar: utcCalendar))
        let biweekly = try #require(RecurrenceCalendar.nextDate(after: start, frequency: .biweekly, anchorDate: start, calendar: utcCalendar))
        let yearly = try #require(RecurrenceCalendar.nextDate(after: start, frequency: .yearly, anchorDate: start, calendar: utcCalendar))
        #expect(utcCalendar.dateComponents([.day], from: start, to: weekly).day == 7)
        #expect(utcCalendar.dateComponents([.day], from: start, to: biweekly).day == 14)
        #expect(utcCalendar.component(.month, from: yearly) == 2)
        #expect(utcCalendar.component(.day, from: yearly) == 28)
    }

    @Test func duplicateOccurrenceDetectionUsesRuleAndOccurrence() {
        let ruleID = UUID()
        let occurrence = date(2026, 11, 7)
        let movement = Movement(
            kind: .expense, amountCents: 1200, title: "Alquiler", date: occurrence,
            accountID: UUID(), isRecurring: true, recurringRuleID: ruleID,
            recurrenceOccurrence: occurrence
        )
        #expect(RecurrenceCalendar.alreadyRecorded(ruleID: ruleID, occurrence: occurrence, movements: [movement]))
        #expect(!RecurrenceCalendar.alreadyRecorded(ruleID: UUID(), occurrence: occurrence, movements: [movement]))
        #expect(!RecurrenceCalendar.alreadyRecorded(ruleID: ruleID, occurrence: date(2026, 12, 7), movements: [movement]))
    }

    @Test func budgetAlertsFireOnlyForCrossedEnabledThresholds() {
        let enabled: Set<BudgetAlertThreshold> = [.eighty, .oneHundred, .exceeded]
        #expect(BudgetAlertThreshold.crossed(spent: 7_999, limit: 10_000, enabled: enabled).isEmpty)
        #expect(BudgetAlertThreshold.crossed(spent: 8_000, limit: 10_000, enabled: enabled) == [.eighty])
        #expect(BudgetAlertThreshold.crossed(spent: 10_000, limit: 10_000, enabled: enabled) == [.eighty, .oneHundred])
        #expect(BudgetAlertThreshold.crossed(spent: 10_001, limit: 10_000, enabled: enabled) == [.eighty, .oneHundred, .exceeded])
        #expect(BudgetAlertThreshold.crossed(spent: 20_000, limit: 0, enabled: enabled).isEmpty)
        #expect(BudgetAlertThreshold.crossed(spent: 9_000, limit: 10_000, enabled: [.oneHundred]).isEmpty)
    }

    @Test func budgetAlertDeduplicationKeyIsStablePerCategoryThresholdAndMonth() {
        let categoryID = UUID()
        let november = date(2026, 11, 1)
        let sameMonth = date(2026, 11, 30)
        let december = date(2026, 12, 1)
        let key = BudgetAlertThreshold.notificationKey(categoryID: categoryID, monthStart: november, threshold: .eighty, calendar: utcCalendar)
        #expect(key == BudgetAlertThreshold.notificationKey(categoryID: categoryID, monthStart: sameMonth, threshold: .eighty, calendar: utcCalendar))
        #expect(key != BudgetAlertThreshold.notificationKey(categoryID: categoryID, monthStart: december, threshold: .eighty, calendar: utcCalendar))
        #expect(key != BudgetAlertThreshold.notificationKey(categoryID: UUID(), monthStart: november, threshold: .eighty, calendar: utcCalendar))
        #expect(key != BudgetAlertThreshold.notificationKey(categoryID: categoryID, monthStart: november, threshold: .oneHundred, calendar: utcCalendar))
    }

    @Test func budgetSpendHonorsMonthExclusionsAndTransfers() {
        let categoryID = UUID()
        let accountID = UUID()
        let range = DateRange(start: date(2026, 11, 1), end: date(2026, 12, 1))
        let valid = Movement(kind: .expense, amountCents: 2_000, title: "Compra", date: date(2026, 11, 7), accountID: accountID, categoryID: categoryID)
        let excluded = Movement(kind: .expense, amountCents: 9_000, title: "Excluido", date: date(2026, 11, 8), accountID: accountID, categoryID: categoryID, isExcluded: true)
        let transfer = Movement(kind: .transfer, amountCents: 8_000, title: "Traspaso", date: date(2026, 11, 9), accountID: accountID, categoryID: categoryID)
        let previousMonth = Movement(kind: .expense, amountCents: 7_000, title: "Octubre", date: date(2026, 10, 31), accountID: accountID, categoryID: categoryID)
        let nextMonth = Movement(kind: .expense, amountCents: 6_000, title: "Diciembre", date: date(2026, 12, 1), accountID: accountID, categoryID: categoryID)
        #expect(Finance.spent(in: categoryID, movements: [valid, excluded, transfer, previousMonth, nextMonth], range: range) == 2_000)
    }

    @Test func legacyRecurringMovementFlagIsPreservedWithoutInventingRule() {
        let oldMovement = Movement(
            kind: .expense, amountCents: 4_500, title: "Pago existente",
            date: date(2026, 11, 1), accountID: UUID(), isRecurring: true
        )
        #expect(oldMovement.isRecurring)
        #expect(oldMovement.recurringRuleID == nil)
        #expect(oldMovement.recurrenceOccurrence == nil)
    }

    @Test func versionOneBackupRestoresRecurringMovementAndExistingRecords() throws {
        let schema = Schema([Account.self, MovementCategory.self, Movement.self, Budget.self, RecurringRule.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let accountID = UUID()
        let movementID = UUID()
        let dateText = "2026-11-01T00:00:00Z"
        let legacyHeader = Backup.legacyHeader

        func csvRow(_ values: [String: String]) -> String {
            CSV.row(legacyHeader.map { values[$0] ?? "" }, delimiter: ",")
        }

        let contents = [
            CSV.row(legacyHeader, delimiter: ","),
            csvRow(["record": "meta", "kind": Backup.marker, "amount_cents": "1", "name": "Yeray", "notes": "EUR"]),
            csvRow(["record": "account", "id": accountID.uuidString, "name": "Cuenta", "amount_cents": "10000", "date": dateText, "color": "#2F5BFF", "icon": "building.columns.fill", "account_type": "checking", "created_at": dateText]),
            csvRow(["record": "movement", "id": movementID.uuidString, "name": "Pago recurrente", "kind": "expense", "amount_cents": "4500", "date": dateText, "account_id": accountID.uuidString, "recurring": "1", "created_at": dateText]),
        ].joined(separator: "\n") + "\n"

        let settings = AppSettings()
        let summary = try Backup.restore(contents, context: container.mainContext, settings: settings)
        let restoredMovements = try container.mainContext.fetch(FetchDescriptor<Movement>())
        let restoredAccounts = try container.mainContext.fetch(FetchDescriptor<Account>())
        #expect(summary.accounts == 1)
        #expect(summary.movements == 1)
        #expect(restoredAccounts.first?.id == accountID)
        #expect(restoredMovements.first?.id == movementID)
        #expect(restoredMovements.first?.isRecurring == true)
        #expect(restoredMovements.first?.recurringRuleID == nil)
    }
}
