import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

nonisolated struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    static var writableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let s = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        text = s
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

enum CSV {
    static func escape(_ s: String, delimiter: Character) -> String {
        if s.contains(delimiter) || s.contains("\"") || s.contains("\n") || s.contains("\r") {
            return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return s
    }

    static func row(_ fields: [String], delimiter: Character) -> String {
        fields.map { escape($0, delimiter: delimiter) }.joined(separator: String(delimiter))
    }

    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text)
        if chars.first == "\u{FEFF}" { chars.removeFirst() }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        field.append("\"")
                        i += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                if c == "\"" {
                    inQuotes = true
                } else if c == delimiter {
                    row.append(field); field = ""
                } else if c == "\n" || c == "\r\n" || c == "\r" {
                    row.append(field); field = ""
                    if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                    row = []
                } else {
                    field.append(c)
                }
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }
}

enum BackupError: LocalizedError {
    case invalidFormat
    case unsupportedVersion
    case badRow(Int)

    var errorDescription: String? {
        switch self {
        case .invalidFormat: "El archivo no es una copia de seguridad válida de la app."
        case .unsupportedVersion: "La copia de seguridad procede de una versión no compatible."
        case .badRow(let n): "La fila \(n) de la copia de seguridad contiene datos no válidos."
        }
    }
}

struct RestoreSummary {
    let accounts: Int
    let categories: Int
    let movements: Int
    let budgets: Int
    let recurringRules: Int
}

enum Backup {
    static let marker = "mybalance-backup"
    static let version = "2"
    private static let legacyVersion = "1"
    static let legacyHeader = [
        "record", "id", "name", "kind", "amount_cents", "date", "account_id", "to_account_id",
        "category_id", "bank_id", "icon", "color", "account_type", "notes", "excluded",
        "recurring", "sort_order", "archived", "created_at", "demo",
    ]
    static let header = legacyHeader + [
        "recurring_rule_id", "recurrence_occurrence", "frequency", "start_date",
        "next_occurrence", "end_date", "rule_active", "anchor_day",
    ]

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoBasic = ISO8601DateFormatter()

    private static func d(_ date: Date) -> String { iso.string(from: date) }
    private static func parseDate(_ s: String) -> Date? { iso.date(from: s) ?? isoBasic.date(from: s) }
    private static func b(_ v: Bool) -> String { v ? "1" : "0" }

    // MARK: Export full backup

    static func makeBackup(accounts: [Account], categories: [MovementCategory], movements: [Movement], budgets: [Budget], recurringRules: [RecurringRule], settings: AppSettings) -> String {
        var lines: [String] = [CSV.row(header, delimiter: ",")]
        func line(_ dict: [String: String]) {
            lines.append(CSV.row(header.map { dict[$0] ?? "" }, delimiter: ","))
        }
        line(["record": "meta", "kind": marker, "name": settings.userName, "amount_cents": version, "notes": settings.currencyCode, "created_at": d(.now)])
        for c in categories {
            line(["record": "category", "id": c.id.uuidString, "name": c.name, "kind": c.kindRaw, "icon": c.icon, "color": c.colorHex, "sort_order": String(c.sortOrder), "created_at": d(c.createdAt), "demo": b(c.isDefault)])
        }
        for a in accounts {
            line(["record": "account", "id": a.id.uuidString, "name": a.name, "amount_cents": String(a.initialBalanceCents), "date": d(a.initialDate), "bank_id": a.bankID ?? "", "icon": a.iconName, "color": a.colorHex, "account_type": a.typeRaw, "sort_order": String(a.sortOrder), "archived": b(a.isArchived), "created_at": d(a.createdAt), "demo": b(a.isDemo)])
        }
        for m in movements {
            line(["record": "movement", "id": m.id.uuidString, "name": m.title, "kind": m.kindRaw, "amount_cents": String(m.amountCents), "date": d(m.date), "account_id": m.accountID.uuidString, "to_account_id": m.toAccountID?.uuidString ?? "", "category_id": m.categoryID?.uuidString ?? "", "notes": m.notes, "excluded": b(m.isExcluded), "recurring": b(m.isRecurring), "created_at": d(m.createdAt), "demo": b(m.isDemo), "recurring_rule_id": m.recurringRuleID?.uuidString ?? "", "recurrence_occurrence": m.recurrenceOccurrence.map(d) ?? ""])
        }
        for bu in budgets {
            line(["record": "budget", "id": bu.id.uuidString, "amount_cents": String(bu.limitCents), "category_id": bu.categoryID.uuidString, "created_at": d(bu.createdAt), "demo": b(bu.isDemo)])
        }
        for rule in recurringRules {
            line(["record": "recurring_rule", "id": rule.id.uuidString, "name": rule.title, "kind": rule.kindRaw, "amount_cents": String(rule.amountCents), "account_id": rule.accountID.uuidString, "category_id": rule.categoryID?.uuidString ?? "", "notes": rule.notes, "excluded": b(rule.isExcluded), "frequency": rule.frequencyRaw, "start_date": d(rule.startDate), "next_occurrence": d(rule.nextOccurrence), "end_date": rule.endDate.map(d) ?? "", "rule_active": b(rule.isActive), "anchor_day": String(rule.anchorDay), "created_at": d(rule.createdAt)])
        }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: Restore

    static func restore(_ text: String, context: ModelContext, settings: AppSettings) throws -> RestoreSummary {
        let rows = CSV.parse(text, delimiter: ",")
        guard let head = rows.first, head == header || head == legacyHeader else { throw BackupError.invalidFormat }
        let inputHeader = head

        var newAccounts: [Account] = []
        var newCategories: [MovementCategory] = []
        var newMovements: [Movement] = []
        var newBudgets: [Budget] = []
        var newRules: [RecurringRule] = []
        var meta: [String: String]?

        for (index, raw) in rows.dropFirst().enumerated() {
            let rowNumber = index + 2
            guard raw.count == inputHeader.count else { throw BackupError.badRow(rowNumber) }
            var r: [String: String] = [:]
            for (i, key) in inputHeader.enumerated() { r[key] = raw[i] }
            let record = r["record"] ?? ""
            func uuid(_ k: String) -> UUID? { UUID(uuidString: r[k] ?? "") }
            func int(_ k: String) -> Int? { Int(r[k] ?? "") }
            func flag(_ k: String) -> Bool { r[k] == "1" }

            switch record {
            case "meta":
                meta = r
            case "category":
                guard let id = uuid("id"), let kind = CategoryKind(rawValue: r["kind"] ?? ""), !(r["name"] ?? "").isEmpty else { throw BackupError.badRow(rowNumber) }
                newCategories.append(MovementCategory(id: id, name: r["name"] ?? "", icon: r["icon"] ?? "tag.fill", colorHex: r["color"] ?? "#94A3B8", kind: kind, sortOrder: int("sort_order") ?? 0, isDefault: flag("demo"), createdAt: parseDate(r["created_at"] ?? "") ?? .now))
            case "account":
                guard let id = uuid("id"), let cents = int("amount_cents"), let date = parseDate(r["date"] ?? "") else { throw BackupError.badRow(rowNumber) }
                let bank = r["bank_id"] ?? ""
                newAccounts.append(Account(id: id, name: r["name"] ?? "Cuenta", bankID: bank.isEmpty ? nil : bank, colorHex: r["color"] ?? "#2F5BFF", iconName: r["icon"] ?? "building.columns.fill", type: AccountType(rawValue: r["account_type"] ?? "") ?? .other, initialBalanceCents: cents, initialDate: date, isArchived: flag("archived"), sortOrder: int("sort_order") ?? 0, isDemo: flag("demo"), createdAt: parseDate(r["created_at"] ?? "") ?? .now))
            case "movement":
                guard let id = uuid("id"), let kind = MovementKind(rawValue: r["kind"] ?? ""), let cents = int("amount_cents"), cents > 0, let date = parseDate(r["date"] ?? ""), let account = uuid("account_id") else { throw BackupError.badRow(rowNumber) }
                newMovements.append(Movement(id: id, kind: kind, amountCents: cents, title: r["name"] ?? "", notes: r["notes"] ?? "", date: date, accountID: account, toAccountID: uuid("to_account_id"), categoryID: uuid("category_id"), isExcluded: flag("excluded"), isRecurring: flag("recurring"), recurringRuleID: uuid("recurring_rule_id"), recurrenceOccurrence: parseDate(r["recurrence_occurrence"] ?? ""), isDemo: flag("demo"), createdAt: parseDate(r["created_at"] ?? "") ?? .now))
            case "budget":
                guard let id = uuid("id"), let cents = int("amount_cents"), let cat = uuid("category_id") else { throw BackupError.badRow(rowNumber) }
                newBudgets.append(Budget(id: id, categoryID: cat, limitCents: cents, isDemo: flag("demo"), createdAt: parseDate(r["created_at"] ?? "") ?? .now))
            case "recurring_rule":
                guard let id = uuid("id"),
                      let kind = MovementKind(rawValue: r["kind"] ?? ""), kind != .transfer,
                      let cents = int("amount_cents"), cents > 0,
                      let account = uuid("account_id"),
                      let frequency = RecurrenceFrequency(rawValue: r["frequency"] ?? ""),
                      let start = parseDate(r["start_date"] ?? ""),
                      let next = parseDate(r["next_occurrence"] ?? ""),
                      let anchorDay = int("anchor_day"), (1...31).contains(anchorDay) else { throw BackupError.badRow(rowNumber) }
                let end = (r["end_date"] ?? "").isEmpty ? nil : parseDate(r["end_date"] ?? "")
                newRules.append(RecurringRule(id: id, kind: kind, amountCents: cents, title: r["name"] ?? "", notes: r["notes"] ?? "", accountID: account, categoryID: uuid("category_id"), isExcluded: flag("excluded"), frequency: frequency, startDate: start, nextOccurrence: next, endDate: end, anchorDay: anchorDay, isActive: flag("rule_active"), createdAt: parseDate(r["created_at"] ?? "") ?? .now))
            default:
                throw BackupError.badRow(rowNumber)
            }
        }

        guard let meta, meta["kind"] == marker else { throw BackupError.invalidFormat }
        let expectedVersion = inputHeader == legacyHeader ? legacyVersion : version
        guard meta["amount_cents"] == expectedVersion else { throw BackupError.unsupportedVersion }

        // Validated: replace everything atomically.
        Seed.wipeAll(context)
        newCategories.forEach { context.insert($0) }
        newAccounts.forEach { context.insert($0) }
        newMovements.forEach { context.insert($0) }
        newBudgets.forEach { context.insert($0) }
        newRules.forEach { context.insert($0) }
        try context.save()

        settings.userName = meta["name"] ?? ""
        if let code = meta["notes"], !code.isEmpty { settings.currencyCode = code }
        UserDefaults.standard.set(true, forKey: Seed.seededKey)

        return RestoreSummary(accounts: newAccounts.count, categories: newCategories.count, movements: newMovements.count, budgets: newBudgets.count, recurringRules: newRules.count)
    }

    // MARK: Human-readable movements CSV (Spanish Excel style)

    static func movementsCSV(_ movements: [Movement], lookup: Lookup) -> String {
        var lines = [CSV.row(["Fecha", "Tipo", "Descripción", "Importe", "Moneda", "Cuenta", "Cuenta destino", "Categoría", "Notas", "Excluido de estadísticas"], delimiter: ";")]
        for m in movements.sorted(by: { $0.date > $1.date }) {
            let signed: Int = switch m.kind {
            case .expense: -m.amountCents
            case .income: m.amountCents
            case .transfer: m.amountCents
            }
            let amount = (signed < 0 ? "-" : "") + Money.editString(abs(signed))
            lines.append(CSV.row([
                Fmt.date(m.date),
                m.kind.label,
                m.title,
                amount,
                Money.symbol,
                lookup.accountName(m.accountID),
                m.kind == .transfer ? lookup.accountName(m.toAccountID) : "",
                lookup.category(m.categoryID)?.name ?? "",
                m.notes,
                m.isExcluded ? "Sí" : "No",
            ], delimiter: ";"))
        }
        return "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
    }
}
