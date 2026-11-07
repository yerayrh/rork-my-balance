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
        #expect(BudgetAlertThreshold.crossed(spent: 9_000, limit: 10_000, enabled: enabled) == [.eighty])
        #expect(BudgetAlertThreshold.crossed(spent: 10_000, limit: 10_000, enabled: enabled) == [.oneHundred])
        #expect(BudgetAlertThreshold.crossed(spent: 10_001, limit: 10_000, enabled: enabled) == [.exceeded])
        #expect(BudgetAlertThreshold.crossed(spent: 10_001, limit: 10_000, enabled: [.eighty, .oneHundred]) == [.oneHundred])
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

    @Test func shortcutRejectsMissingCategoryOrAccount() {
        #expect(throws: ShortcutFinanceError.self) {
            try ShortcutFinanceValidation.validateSelection(categoryID: nil, accountID: UUID())
        }
        #expect(throws: ShortcutFinanceError.self) {
            try ShortcutFinanceValidation.validateSelection(categoryID: UUID(), accountID: nil)
        }
        #expect(throws: ShortcutFinanceError.self) {
            try ShortcutFinanceValidation.validateSelection(categoryID: nil, accountID: nil)
        }
    }

    @Test func shortcutRejectsInvalidAmountsAndConvertsValidAmountToCents() throws {
        for invalid in [0.0, -1.0, 1.001, Double.infinity, Double.nan] {
            #expect(throws: ShortcutFinanceError.self) {
                try ShortcutFinanceValidation.amountCents(invalid)
            }
        }
        #expect(try ShortcutFinanceValidation.amountCents(12.34) == 1_234)
    }

    @Test func shortcutListsExistingAccountsAndKindSpecificCategoriesAndSavesSelectedValues() throws {
        let schema = Schema([Account.self, MovementCategory.self, Movement.self, Budget.self, RecurringRule.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let account = Account(name: "Cuenta diaria", colorHex: "#123456", iconName: "creditcard.fill", type: .checking, initialBalanceCents: 0, initialDate: date(2026, 1, 1))
        let archived = Account(name: "Archivada", colorHex: "#123456", iconName: "creditcard.fill", type: .checking, initialBalanceCents: 0, initialDate: date(2026, 1, 1), isArchived: true)
        let expense = MovementCategory(name: "Comida", icon: "fork.knife", colorHex: "#123456", kind: .expense)
        let income = MovementCategory(name: "Nómina", icon: "briefcase.fill", colorHex: "#123456", kind: .income)
        [account, archived].forEach(context.insert)
        [expense, income].forEach(context.insert)
        try context.save()

        let settings = AppSettings()
        settings.accountBalancesVisible = true
        let lockManager = LockManager()
        lockManager.isLocked = false
        let store = ShortcutFinanceStore(container: container, settings: settings, router: AppRouter(), lockManager: lockManager)

        #expect(Set(try store.accounts().map(\.id)) == [account.id])
        #expect(Set(try store.categories(for: .expense).map(\.id)) == [expense.id])
        #expect(Set(try store.categories(for: .income).map(\.id)) == [income.id])

        try store.saveMovement(kind: .expense, amount: 8.75, categoryID: expense.id, accountID: account.id, date: date(2026, 11, 7), note: "Café")
        let saved = try context.fetch(FetchDescriptor<Movement>())
        #expect(saved.count == 1)
        #expect(saved[0].accountID == account.id)
        #expect(saved[0].categoryID == expense.id)
        #expect(saved[0].kind == .expense)
        #expect(saved[0].amountCents == 875)
        #expect(saved[0].notes == "Café")

        #expect(throws: ShortcutFinanceError.self) {
            try store.saveMovement(kind: .expense, amount: 2, categoryID: income.id, accountID: account.id, date: date(2026, 11, 7), note: nil)
        }
        #expect(throws: ShortcutFinanceError.self) {
            try store.saveMovement(kind: .expense, amount: 2, categoryID: expense.id, accountID: archived.id, date: date(2026, 11, 7), note: nil)
        }

        try store.saveMovement(kind: .income, amount: 1_250, categoryID: income.id, accountID: account.id, date: date(2026, 11, 7), note: nil)
        let withIncome = try context.fetch(FetchDescriptor<Movement>())
        #expect(withIncome.count == 2)
        #expect(withIncome.contains { $0.kind == .income && $0.categoryID == income.id && $0.amountCents == 125_000 })
    }

    @Test func shortcutMonthlyExpenseReadUsesStatisticsRulesAndHonorsPrivacy() throws {
        let schema = Schema([Account.self, MovementCategory.self, Movement.self, Budget.self, RecurringRule.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let accountID = UUID()
        let movements = [
            Movement(kind: .expense, amountCents: 2_500, title: "Gasto actual", date: date(2026, 11, 4), accountID: accountID),
            Movement(kind: .expense, amountCents: 9_000, title: "Excluido", date: date(2026, 11, 5), accountID: accountID, isExcluded: true),
            Movement(kind: .income, amountCents: 7_000, title: "Ingreso", date: date(2026, 11, 6), accountID: accountID),
            Movement(kind: .expense, amountCents: 8_000, title: "Mes anterior", date: date(2026, 10, 31), accountID: accountID),
        ]
        movements.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()

        let settings = AppSettings()
        settings.accountBalancesVisible = true
        let lockManager = LockManager()
        lockManager.isLocked = false
        let store = ShortcutFinanceStore(container: container, settings: settings, router: AppRouter(), lockManager: lockManager)
        #expect(try store.currentMonthExpenses(now: date(2026, 11, 7)) == 2_500)

        settings.accountBalancesVisible = false
        #expect(throws: ShortcutFinanceError.self) {
            try store.currentMonthExpenses(now: date(2026, 11, 7))
        }
    }
}
