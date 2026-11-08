import Foundation
import SwiftData

// MARK: - Enums

enum MovementKind: String, CaseIterable, Identifiable, Codable {
    case expense, income, transfer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expense: "Gasto"
        case .income: "Ingreso"
        case .transfer: "Transferencia"
        }
    }

    var pluralLabel: String {
        switch self {
        case .expense: "Gastos"
        case .income: "Ingresos"
        case .transfer: "Transferencias"
        }
    }

    var categoryKind: CategoryKind? {
        switch self {
        case .expense: .expense
        case .income: .income
        case .transfer: nil
        }
    }
}

enum AccountType: String, CaseIterable, Identifiable, Codable {
    case checking, savings, cash, card, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .checking: "Corriente"
        case .savings: "Ahorro"
        case .cash: "Efectivo"
        case .card: "Tarjeta"
        case .other: "Otra"
        }
    }

    var defaultIcon: String {
        switch self {
        case .checking: "building.columns.fill"
        case .savings: "banknote.fill"
        case .cash: "dollarsign.circle.fill"
        case .card: "creditcard.fill"
        case .other: "wallet.bifold.fill"
        }
    }
}

enum CategoryKind: String, CaseIterable, Identifiable, Codable {
    case expense, income

    var id: String { rawValue }

    var label: String {
        switch self {
        case .expense: "Gastos"
        case .income: "Ingresos"
        }
    }
}

// MARK: - Account

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var bankID: String?
    var colorHex: String
    var iconName: String
    var typeRaw: String
    var initialBalanceCents: Int
    var initialDate: Date
    var isArchived: Bool
    var sortOrder: Int
    var isDemo: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        bankID: String? = nil,
        colorHex: String,
        iconName: String,
        type: AccountType,
        initialBalanceCents: Int,
        initialDate: Date,
        isArchived: Bool = false,
        sortOrder: Int = 0,
        isDemo: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.bankID = bankID
        self.colorHex = colorHex
        self.iconName = iconName
        self.typeRaw = type.rawValue
        self.initialBalanceCents = initialBalanceCents
        self.initialDate = initialDate
        self.isArchived = isArchived
        self.sortOrder = sortOrder
        self.isDemo = isDemo
        self.createdAt = createdAt
    }

    var type: AccountType {
        get { AccountType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var bank: Bank? { bankID.flatMap { BankCatalog.byID[$0] } }
}

// MARK: - Category

@Model
final class MovementCategory {
    @Attribute(.unique) var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var kindRaw: String
    var sortOrder: Int
    var isDefault: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorHex: String,
        kind: CategoryKind,
        sortOrder: Int = 0,
        isDefault: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }
}

// MARK: - Movement

@Model
final class Movement {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    /// Always positive, in cents. The sign comes from `kind`.
    var amountCents: Int
    var title: String
    var notes: String
    var date: Date
    var accountID: UUID
    var toAccountID: UUID?
    var categoryID: UUID?
    var isExcluded: Bool
    var isRecurring: Bool
    var recurringRuleID: UUID?
    var recurrenceOccurrence: Date?
    var isDemo: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        kind: MovementKind,
        amountCents: Int,
        title: String,
        notes: String = "",
        date: Date,
        accountID: UUID,
        toAccountID: UUID? = nil,
        categoryID: UUID? = nil,
        isExcluded: Bool = false,
        isRecurring: Bool = false,
        recurringRuleID: UUID? = nil,
        recurrenceOccurrence: Date? = nil,
        isDemo: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.amountCents = amountCents
        self.title = title
        self.notes = notes
        self.date = date
        self.accountID = accountID
        self.toAccountID = toAccountID
        self.categoryID = categoryID
        self.isExcluded = isExcluded
        self.isRecurring = isRecurring
        self.recurringRuleID = recurringRuleID
        self.recurrenceOccurrence = recurrenceOccurrence
        self.isDemo = isDemo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var kind: MovementKind {
        get { MovementKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }
}

// MARK: - Budget

@Model
final class Budget {
    @Attribute(.unique) var id: UUID
    var categoryID: UUID
    var limitCents: Int
    var isDemo: Bool
    var createdAt: Date

    init(id: UUID = UUID(), categoryID: UUID, limitCents: Int, isDemo: Bool = false, createdAt: Date = .now) {
        self.id = id
        self.categoryID = categoryID
        self.limitCents = limitCents
        self.isDemo = isDemo
        self.createdAt = createdAt
    }
}

// MARK: - Recurring movement rules

enum RecurrenceFrequency: String, CaseIterable, Identifiable, Codable {
    case weekly, biweekly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly: "Cada semana"
        case .biweekly: "Cada dos semanas"
        case .monthly: "Cada mes"
        case .yearly: "Cada año"
        }
    }
}

@Model
final class RecurringRule {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var amountCents: Int
    var title: String
    var notes: String
    var accountID: UUID
    var categoryID: UUID?
    var isExcluded: Bool
    var frequencyRaw: String
    var startDate: Date
    var nextOccurrence: Date
    var endDate: Date?
    var anchorDay: Int
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        kind: MovementKind,
        amountCents: Int,
        title: String,
        notes: String = "",
        accountID: UUID,
        categoryID: UUID? = nil,
        isExcluded: Bool = false,
        frequency: RecurrenceFrequency,
        startDate: Date,
        nextOccurrence: Date,
        endDate: Date? = nil,
        anchorDay: Int,
        isActive: Bool = true,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.amountCents = amountCents
        self.title = title
        self.notes = notes
        self.accountID = accountID
        self.categoryID = categoryID
        self.isExcluded = isExcluded
        self.frequencyRaw = frequency.rawValue
        self.startDate = startDate
        self.nextOccurrence = nextOccurrence
        self.endDate = endDate
        self.anchorDay = anchorDay
        self.isActive = isActive
        self.createdAt = createdAt
    }

    var kind: MovementKind { MovementKind(rawValue: kindRaw) ?? .expense }
    var frequency: RecurrenceFrequency { RecurrenceFrequency(rawValue: frequencyRaw) ?? .monthly }
}

// MARK: - Lookup

struct Lookup {
    let accounts: [UUID: Account]
    let categories: [UUID: MovementCategory]

    init(accounts: [Account], categories: [MovementCategory]) {
        self.accounts = Dictionary(accounts.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        self.categories = Dictionary(categories.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func accountName(_ id: UUID?) -> String {
        guard let id else { return "—" }
        return accounts[id]?.name ?? "Cuenta eliminada"
    }

    func category(_ id: UUID?) -> MovementCategory? {
        guard let id else { return nil }
        return categories[id]
    }
}
