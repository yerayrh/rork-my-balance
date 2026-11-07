import Foundation
import SwiftData

enum Seed {
    static let expenseDefaults: [(String, String, String)] = [
        ("Vivienda", "house.fill", "#2F5BFF"),
        ("Alimentación", "cart.fill", "#19C37D"),
        ("Restaurantes", "fork.knife", "#FF7A2F"),
        ("Transporte", "bus.fill", "#0EA5E9"),
        ("Gasolina", "fuelpump.fill", "#F59E0B"),
        ("Compras", "bag.fill", "#FF5C8A"),
        ("Ropa", "tshirt.fill", "#A855F7"),
        ("Tecnología", "laptopcomputer", "#6366F1"),
        ("Ocio", "gamecontroller.fill", "#EC4899"),
        ("Viajes", "airplane", "#14B8A6"),
        ("Salud", "heart.fill", "#EF4444"),
        ("Farmacia", "pills.fill", "#10B981"),
        ("Deporte", "figure.run", "#84CC16"),
        ("Educación", "book.fill", "#3B82F6"),
        ("Suscripciones", "repeat", "#8B5CF6"),
        ("Mascotas", "pawprint.fill", "#D97706"),
        ("Regalos", "gift.fill", "#F43F5E"),
        ("Seguros", "shield.fill", "#0891B2"),
        ("Impuestos", "building.columns.fill", "#64748B"),
        ("Otros", "ellipsis.circle.fill", "#94A3B8"),
    ]

    static let incomeDefaults: [(String, String, String)] = [
        ("Nómina", "briefcase.fill", "#19C37D"),
        ("Ingresos extraordinarios", "sparkles", "#F59E0B"),
        ("Inversiones", "chart.line.uptrend.xyaxis", "#2F5BFF"),
        ("Alquileres", "key.fill", "#8B5CF6"),
        ("Devoluciones", "arrow.uturn.backward.circle.fill", "#0EA5E9"),
        ("Otros ingresos", "plus.circle.fill", "#94A3B8"),
    ]

    static let seededKey = "didSeedCategories"

    static func ensureCategories(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: seededKey) else { return }
        let count = (try? context.fetchCount(FetchDescriptor<MovementCategory>())) ?? 0
        if count == 0 { insertDefaultCategories(context) }
        UserDefaults.standard.set(true, forKey: seededKey)
        try? context.save()
    }

    static func insertDefaultCategories(_ context: ModelContext) {
        for (i, c) in expenseDefaults.enumerated() {
            context.insert(MovementCategory(name: c.0, icon: c.1, colorHex: c.2, kind: .expense, sortOrder: i, isDefault: true))
        }
        for (i, c) in incomeDefaults.enumerated() {
            context.insert(MovementCategory(name: c.0, icon: c.1, colorHex: c.2, kind: .income, sortOrder: i, isDefault: true))
        }
    }

    // MARK: - Demo data (clearly flagged, removable from Settings)

    private struct SeededRandom {
        var state: UInt64
        mutating func next(_ range: ClosedRange<Int>) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let span = UInt64(range.upperBound - range.lowerBound + 1)
            return range.lowerBound + Int((state >> 33) % span)
        }
    }

    static func loadDemo(_ context: ModelContext) {
        let cats = (try? context.fetch(FetchDescriptor<MovementCategory>())) ?? []
        if cats.isEmpty { insertDefaultCategories(context) }
        let all = (try? context.fetch(FetchDescriptor<MovementCategory>())) ?? []
        func cat(_ name: String) -> UUID? { all.first { $0.name == name }?.id }

        let existing = (try? context.fetchCount(FetchDescriptor<Account>())) ?? 0
        let now = Date()
        let start = now.startOfMonth.addingMonths(-4)

        let bbva = Account(name: "BBVA", bankID: "bbva", colorHex: "#004481", iconName: "building.columns.fill", type: .checking, initialBalanceCents: 2_450_00, initialDate: start, sortOrder: existing, isDemo: true)
        let revolut = Account(name: "Revolut", bankID: "revolut", colorHex: "#191C1F", iconName: "creditcard.fill", type: .checking, initialBalanceCents: 380_00, initialDate: start, sortOrder: existing + 1, isDemo: true)
        let ing = Account(name: "ING Ahorro", bankID: "ing-es", colorHex: "#FF6200", iconName: "banknote.fill", type: .savings, initialBalanceCents: 5_000_00, initialDate: start, sortOrder: existing + 2, isDemo: true)
        [bbva, revolut, ing].forEach { context.insert($0) }

        var rng = SeededRandom(state: 42)

        func add(_ kind: MovementKind, _ cents: Int, _ title: String, _ date: Date, _ account: Account, to: Account? = nil, cat name: String? = nil, excluded: Bool = false) {
            guard date <= now else { return }
            context.insert(Movement(kind: kind, amountCents: cents, title: title, date: date, accountID: account.id, toAccountID: to?.id, categoryID: name.flatMap(cat), isExcluded: excluded, isDemo: true))
        }

        for offset in 0...4 {
            let month = start.addingMonths(offset)
            func day(_ d: Int, _ h: Int = 10) -> Date {
                let base = month.addingDays(d - 1)
                return Calendar.app.date(bySettingHour: h, minute: rng.next(0...59), second: 0, of: base) ?? base
            }
            add(.income, 2_350_00, "Nómina", day(1, 8), bbva, cat: "Nómina")
            add(.expense, 650_00, "Alquiler piso", day(2), bbva, cat: "Vivienda")
            add(.transfer, 300_00, "Gastos del mes", day(3), bbva, to: revolut)
            add(.transfer, 200_00, "Hucha de ahorro", day(3, 11), bbva, to: ing)
            add(.expense, 12_99, "Netflix", day(5), revolut, cat: "Suscripciones")
            add(.expense, 10_99, "Spotify", day(10), revolut, cat: "Suscripciones")
            add(.expense, rng.next(42_00...68_00), "Luz y agua", day(8), bbva, cat: "Vivienda")
            let shops = ["Mercadona", "Lidl", "Carrefour", "Mercadona"]
            for (i, d) in [4, 11, 18, 25].enumerated() {
                add(.expense, rng.next(38_00...96_00), shops[i], day(d, 19), bbva, cat: "Alimentación")
            }
            let restaurants = ["La Tagliatella", "Sushi Bar Kio", "Bar Manolo"]
            for i in 0..<3 {
                add(.expense, rng.next(14_00...58_00), restaurants[i], day(6 + i * 8, 21), revolut, cat: "Restaurantes")
            }
            add(.expense, rng.next(55_00...72_00), "Repsol", day(14), bbva, cat: "Gasolina")
            add(.expense, 21_80, "Abono transporte", day(1, 9), revolut, cat: "Transporte")
            add(.expense, rng.next(18_00...45_00), "Cine y palomitas", day(16, 22), revolut, cat: "Ocio")
            if offset % 2 == 0 {
                add(.expense, rng.next(29_00...79_00), "Zara", day(20, 18), revolut, cat: "Ropa")
                add(.expense, rng.next(8_00...22_00), "Farmacia Centro", day(12), bbva, cat: "Farmacia")
            } else {
                add(.expense, 39_90, "Gimnasio", day(2, 7), bbva, cat: "Deporte")
                add(.income, rng.next(25_00...120_00), "Devolución Amazon", day(17), revolut, cat: "Devoluciones")
            }
        }
        add(.expense, 25_00, "Compra de prueba", now.startOfDay.addingTimeInterval(9 * 3600), revolut, cat: "Compras", excluded: true)

        if let a = cat("Alimentación") { context.insert(Budget(categoryID: a, limitCents: 300_00, isDemo: true)) }
        if let r = cat("Restaurantes") { context.insert(Budget(categoryID: r, limitCents: 100_00, isDemo: true)) }
        if let o = cat("Ocio") { context.insert(Budget(categoryID: o, limitCents: 150_00, isDemo: true)) }

        try? context.save()
    }

    static func removeDemo(_ context: ModelContext) {
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let demoIDs = Set(accounts.filter(\.isDemo).map(\.id))
        let movements = (try? context.fetch(FetchDescriptor<Movement>())) ?? []
        for m in movements where m.isDemo || demoIDs.contains(m.accountID) || (m.toAccountID.map { demoIDs.contains($0) } ?? false) {
            context.delete(m)
        }
        for a in accounts where a.isDemo { context.delete(a) }
        let budgets = (try? context.fetch(FetchDescriptor<Budget>())) ?? []
        for b in budgets where b.isDemo { context.delete(b) }
        try? context.save()
    }

    static func wipeAll(_ context: ModelContext) {
        ((try? context.fetch(FetchDescriptor<Movement>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<Account>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<Budget>())) ?? []).forEach { context.delete($0) }
        ((try? context.fetch(FetchDescriptor<MovementCategory>())) ?? []).forEach { context.delete($0) }
        try? context.save()
    }
}
