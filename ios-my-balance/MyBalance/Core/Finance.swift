import Foundation

/// Half-open date range [start, end).
struct DateRange: Equatable {
    var start: Date
    var end: Date

    func contains(_ d: Date) -> Bool { d >= start && d < end }

    var dayCount: Int {
        max(1, Calendar.app.dateComponents([.day], from: start.startOfDay, to: end.startOfDay).day ?? 1)
    }

    var monthStarts: [Date] {
        var result: [Date] = []
        var m = start.startOfMonth
        while m < end && result.count < 240 {
            result.append(m)
            m = m.addingMonths(1)
        }
        return result
    }

    static func month(_ d: Date) -> DateRange {
        DateRange(start: d.startOfMonth, end: d.startOfNextMonth)
    }
}

enum StatsPeriod: String, CaseIterable, Identifiable {
    case thisMonth, lastMonth, last3, last6, last12, thisYear, lastYear, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .thisMonth: "Este mes"
        case .lastMonth: "Mes anterior"
        case .last3: "Últimos 3 meses"
        case .last6: "Últimos 6 meses"
        case .last12: "Últimos 12 meses"
        case .thisYear: "Este año"
        case .lastYear: "Año anterior"
        case .custom: "Personalizado"
        }
    }

    func range(now: Date = .now, customStart: Date, customEnd: Date) -> DateRange {
        let m = now.startOfMonth
        switch self {
        case .thisMonth: return DateRange(start: m, end: m.addingMonths(1))
        case .lastMonth: return DateRange(start: m.addingMonths(-1), end: m)
        case .last3: return DateRange(start: m.addingMonths(-2), end: m.addingMonths(1))
        case .last6: return DateRange(start: m.addingMonths(-5), end: m.addingMonths(1))
        case .last12: return DateRange(start: m.addingMonths(-11), end: m.addingMonths(1))
        case .thisYear: return DateRange(start: now.startOfYear, end: now.startOfYear.addingYears(1))
        case .lastYear: return DateRange(start: now.startOfYear.addingYears(-1), end: now.startOfYear)
        case .custom:
            let a = min(customStart, customEnd).startOfDay
            let b = max(customStart, customEnd).startOfDay.addingDays(1)
            return DateRange(start: a, end: b)
        }
    }

    func previous(of r: DateRange) -> DateRange {
        switch self {
        case .custom:
            return DateRange(start: r.start.addingDays(-r.dayCount), end: r.start)
        case .thisYear, .lastYear:
            return DateRange(start: r.start.addingYears(-1), end: r.start)
        default:
            let n = r.monthStarts.count
            return DateRange(start: r.start.addingMonths(-n), end: r.start)
        }
    }
}

struct Totals {
    var income: Int = 0
    var expense: Int = 0
    var net: Int { income - expense }
}

struct CategorySlice: Identifiable {
    let id: String
    let categoryID: UUID?
    let name: String
    let icon: String
    let colorHex: String
    let cents: Int
    let share: Double

    var amount: Double { Double(cents) / 100 }
}

struct BalancePoint: Identifiable {
    let date: Date
    let cents: Int
    var id: Date { date }
    var amount: Double { Double(cents) / 100 }
}

enum Finance {
    // MARK: Balances (real money — exclusions never apply here)

    static func effect(of m: Movement, on accountID: UUID) -> Int {
        switch m.kind {
        case .income:
            return m.accountID == accountID ? m.amountCents : 0
        case .expense:
            return m.accountID == accountID ? -m.amountCents : 0
        case .transfer:
            var r = 0
            if m.accountID == accountID { r -= m.amountCents }
            if m.toAccountID == accountID { r += m.amountCents }
            return r
        }
    }

    /// Balance of an account. Movements dated before the initial-balance date are
    /// already reflected in the initial balance and are therefore ignored.
    static func balance(of account: Account, in movements: [Movement], before: Date? = nil) -> Int {
        let start = account.initialDate.startOfDay
        var total = account.initialBalanceCents
        for m in movements where m.date >= start {
            if let before, m.date >= before { continue }
            total += effect(of: m, on: account.id)
        }
        return total
    }

    static func balances(_ accounts: [Account], _ movements: [Movement]) -> [UUID: Int] {
        var result: [UUID: Int] = [:]
        for a in accounts { result[a.id] = balance(of: a, in: movements) }
        return result
    }

    /// Total money across the given accounts. Transfers between them net to zero.
    static func total(_ accounts: [Account], _ movements: [Movement], before: Date? = nil) -> Int {
        accounts.reduce(0) { sum, a in
            if let before, a.initialDate.startOfDay >= before { return sum }
            return sum + balance(of: a, in: movements, before: before)
        }
    }

    struct MonthChange {
        let delta: Int
        let percent: Double?
    }

    static func monthChange(_ accounts: [Account], _ movements: [Movement], now: Date = .now) -> MonthChange? {
        let boundary = now.startOfMonth
        guard let earliest = accounts.map({ $0.initialDate.startOfDay }).min(), earliest < boundary else { return nil }
        let previous = total(accounts, movements, before: boundary)
        let current = total(accounts, movements)
        let delta = current - previous
        let pct: Double? = previous != 0 ? Double(delta) / Double(abs(previous)) : nil
        return MonthChange(delta: delta, percent: pct)
    }

    static func patrimonySeries(_ accounts: [Account], _ movements: [Movement], from: Date, to: Date = .now, buckets: Int = 24) -> [BalancePoint] {
        guard !accounts.isEmpty else { return [] }
        let start = min(from, to.addingDays(-1))
        let step = to.timeIntervalSince(start) / Double(buckets)
        var points: [BalancePoint] = []
        for i in 0..<buckets {
            let d = start.addingTimeInterval(step * Double(i))
            points.append(BalancePoint(date: d, cents: total(accounts, movements, before: d)))
        }
        points.append(BalancePoint(date: to, cents: total(accounts, movements)))
        return points
    }

    // MARK: Statistics (exclusions and transfers never count)

    static func statMovements(
        _ movements: [Movement],
        range: DateRange,
        accountID: UUID? = nil,
        categoryID: UUID? = nil
    ) -> [Movement] {
        movements.filter { m in
            guard !m.isExcluded, m.kind != .transfer, range.contains(m.date) else { return false }
            if let accountID, m.accountID != accountID { return false }
            if let categoryID, m.categoryID != categoryID { return false }
            return true
        }
    }

    static func totals(_ movements: [Movement]) -> Totals {
        var t = Totals()
        for m in movements where !m.isExcluded {
            switch m.kind {
            case .income: t.income += m.amountCents
            case .expense: t.expense += m.amountCents
            case .transfer: break
            }
        }
        return t
    }

    static func breakdown(_ movements: [Movement], kind: MovementKind = .expense, lookup: Lookup) -> [CategorySlice] {
        var sums: [UUID?: Int] = [:]
        var total = 0
        for m in movements where m.kind == kind && !m.isExcluded {
            sums[m.categoryID, default: 0] += m.amountCents
            total += m.amountCents
        }
        guard total > 0 else { return [] }
        return sums.map { key, cents in
            let cat = lookup.category(key)
            return CategorySlice(
                id: key?.uuidString ?? "none",
                categoryID: key,
                name: cat?.name ?? "Sin categoría",
                icon: cat?.icon ?? "questionmark.circle.fill",
                colorHex: cat?.colorHex ?? "#94A3B8",
                cents: cents,
                share: Double(cents) / Double(total)
            )
        }
        .sorted { $0.cents > $1.cents }
    }

    static func spent(in categoryID: UUID, movements: [Movement], range: DateRange) -> Int {
        statMovements(movements, range: range, categoryID: categoryID)
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amountCents }
    }
}
