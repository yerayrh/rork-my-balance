import AppIntents
import Foundation
import SwiftData

/// The shortcut service is injected with the app's existing container. It never
/// opens a second store, so actions and the SwiftUI app share the same records.
@MainActor
final class ShortcutFinanceStore {
    private let container: ModelContainer
    private let settings: AppSettings
    private let router: AppRouter
    private let lockManager: LockManager

    init(container: ModelContainer, settings: AppSettings, router: AppRouter, lockManager: LockManager) {
        self.container = container
        self.settings = settings
        self.router = router
        self.lockManager = lockManager
    }

    func accounts() throws -> [ShortcutAccount] {
        try container.mainContext.fetch(FetchDescriptor<Account>(sortBy: [SortDescriptor(\.sortOrder)]))
            .filter { !$0.isArchived }
            .map { ShortcutAccount(id: $0.id, name: $0.name) }
    }

    func categories(for kind: CategoryKind) throws -> [ShortcutCategory] {
        try container.mainContext.fetch(FetchDescriptor<MovementCategory>(sortBy: [SortDescriptor(\.sortOrder)]))
            .filter { $0.kind == kind }
            .map { ShortcutCategory(id: $0.id, name: $0.name) }
    }

    func saveMovement(
        kind: MovementKind,
        amount: Double,
        categoryID: UUID,
        accountID: UUID,
        date: Date,
        note: String?
    ) throws {
        guard kind == .expense || kind == .income else { throw ShortcutFinanceError.invalidKind }
        try ShortcutFinanceValidation.validateSelection(categoryID: categoryID, accountID: accountID)
        let cents = try ShortcutFinanceValidation.amountCents(amount)
        let context = container.mainContext
        let accounts = try context.fetch(FetchDescriptor<Account>())
        guard let account = accounts.first(where: { $0.id == accountID && !$0.isArchived }) else {
            throw ShortcutFinanceError.accountUnavailable
        }
        let categories = try context.fetch(FetchDescriptor<MovementCategory>())
        guard let category = categories.first(where: { $0.id == categoryID && $0.kind == kind.categoryKind }) else {
            throw ShortcutFinanceError.categoryUnavailable
        }

        let movement = Movement(
            kind: kind,
            amountCents: cents,
            title: "",
            notes: note?.trimmed ?? "",
            date: date,
            accountID: account.id,
            categoryID: category.id
        )
        context.insert(movement)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw ShortcutFinanceError.couldNotSave(error.localizedDescription)
        }
    }

    func currentMonthExpenses(now: Date = .now) throws -> Int {
        guard settings.accountBalancesVisible, !lockManager.isLocked else {
            throw ShortcutFinanceError.privacyModeEnabled
        }
        let movements = try container.mainContext.fetch(FetchDescriptor<Movement>())
        let month = Finance.statMovements(movements, range: .month(now))
            .filter { $0.kind == .expense }
        return Finance.totals(month).expense
    }

    func openBudgets() {
        router.tab = .budgets
    }
}

enum ShortcutFinanceValidation {
    static func validateSelection(categoryID: UUID?, accountID: UUID?) throws {
        guard categoryID != nil else { throw ShortcutFinanceError.categoryUnavailable }
        guard accountID != nil else { throw ShortcutFinanceError.accountUnavailable }
    }

    static func amountCents(_ amount: Double) throws -> Int {
        guard amount.isFinite, amount > 0 else { throw ShortcutFinanceError.invalidAmount }
        let scaled = amount * 100
        guard scaled < Double(Int.max), abs(scaled.rounded() - scaled) < 0.000_001 else {
            throw ShortcutFinanceError.invalidAmount
        }
        return Int(scaled.rounded())
    }
}

enum ShortcutFinanceError: LocalizedError {
    case invalidKind
    case invalidAmount
    case accountUnavailable
    case categoryUnavailable
    case privacyModeEnabled
    case couldNotSave(String)

    var errorDescription: String? {
        switch self {
        case .invalidKind: "Solo se pueden añadir gastos e ingresos desde este atajo."
        case .invalidAmount: "Indica un importe positivo con un máximo de dos decimales."
        case .accountUnavailable: "La cuenta seleccionada ya no está disponible. Elige una cuenta activa."
        case .categoryUnavailable: "La categoría seleccionada no está disponible para este movimiento. Elige otra categoría."
        case .privacyModeEnabled: "Activa la visualización de saldos y desbloquea My Balance para consultar este dato."
        case .couldNotSave(let reason): "No se pudo guardar el movimiento: \(reason)"
        }
    }
}

struct ShortcutAccount: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cuenta")
    static var defaultQuery = ShortcutAccountQuery()

    var id: UUID
    @Property(title: "Nombre") var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

struct ShortcutCategory: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Categoría")
    static var defaultQuery = ShortcutCategoryQuery()

    var id: UUID
    @Property(title: "Nombre") var name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
}

struct ShortcutAccountQuery: EntityQuery {
    @Dependency private var store: ShortcutFinanceStore

    func entities(for identifiers: [UUID]) async throws -> [ShortcutAccount] {
        let accounts = try await store.accounts()
        return accounts.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShortcutAccount] {
        try await store.accounts()
    }
}

struct ShortcutCategoryQuery: EntityQuery {
    @Dependency private var store: ShortcutFinanceStore

    func entities(for identifiers: [UUID]) async throws -> [ShortcutCategory] {
        let expenses = try await store.categories(for: .expense)
        let incomes = try await store.categories(for: .income)
        return (expenses + incomes).filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ShortcutCategory] {
        let expenses = try await store.categories(for: .expense)
        let incomes = try await store.categories(for: .income)
        return expenses + incomes
    }
}

struct AddExpenseShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir gasto"
    static var description = IntentDescription("Guarda un gasto en My Balance.")
    static var openAppWhenRun = false

    @Parameter(title: "Importe") var amount: Double
    @Parameter(title: "Categoría") var category: ShortcutCategory
    @Parameter(title: "Cuenta") var account: ShortcutAccount
    @Parameter(title: "Fecha") var date: Date
    @Parameter(title: "Nota", default: nil) var note: String?

    @Dependency private var store: ShortcutFinanceStore

    static var parameterSummary: some ParameterSummary {
        Summary("Añadir gasto de \(\.$amount) en \(\.$category) desde \(\.$account) el \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await store.saveMovement(kind: .expense, amount: amount, categoryID: category.id, accountID: account.id, date: date, note: note)
        return .result(dialog: "Gasto añadido a My Balance.")
    }
}

struct AddIncomeShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir ingreso"
    static var description = IntentDescription("Guarda un ingreso en My Balance.")
    static var openAppWhenRun = false

    @Parameter(title: "Importe") var amount: Double
    @Parameter(title: "Categoría") var category: ShortcutCategory
    @Parameter(title: "Cuenta") var account: ShortcutAccount
    @Parameter(title: "Fecha") var date: Date
    @Parameter(title: "Nota", default: nil) var note: String?

    @Dependency private var store: ShortcutFinanceStore

    static var parameterSummary: some ParameterSummary {
        Summary("Añadir ingreso de \(\.$amount) en \(\.$category) a \(\.$account) el \(\.$date)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await store.saveMovement(kind: .income, amount: amount, categoryID: category.id, accountID: account.id, date: date, note: note)
        return .result(dialog: "Ingreso añadido a My Balance.")
    }
}

struct CurrentMonthExpensesShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Ver gastos de este mes"
    static var description = IntentDescription("Consulta el total de gastos contabilizados este mes.")
    static var openAppWhenRun = false

    @Dependency private var store: ShortcutFinanceStore

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let cents = try await store.currentMonthExpenses()
        return .result(value: Money.format(cents, sign: .never))
    }
}

struct OpenBudgetsShortcutIntent: AppIntent {
    static var title: LocalizedStringResource = "Abrir Presupuestos"
    static var description = IntentDescription("Abre My Balance en la sección Presupuestos.")
    static var openAppWhenRun = true

    @Dependency private var store: ShortcutFinanceStore

    func perform() async throws -> some IntentResult {
        await store.openBudgets()
        return .result()
    }
}

struct MyBalanceAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseShortcutIntent(),
            phrases: [
                "Añadir gasto en \(.applicationName)",
                "Registrar gasto en \(.applicationName)",
                "Añadir compra tras pagar con Apple Pay en \(.applicationName)"
            ],
            shortTitle: "Añadir gasto",
            systemImageName: "minus.circle"
        )
        AppShortcut(
            intent: AddIncomeShortcutIntent(),
            phrases: ["Añadir ingreso en \(.applicationName)", "Registrar ingreso en \(.applicationName)"],
            shortTitle: "Añadir ingreso",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: CurrentMonthExpensesShortcutIntent(),
            phrases: ["Ver gastos de este mes en \(.applicationName)"],
            shortTitle: "Gastos de este mes",
            systemImageName: "eurosign.circle"
        )
        AppShortcut(
            intent: OpenBudgetsShortcutIntent(),
            phrases: ["Abrir presupuestos en \(.applicationName)"],
            shortTitle: "Abrir Presupuestos",
            systemImageName: "chart.bar"
        )
    }
}
