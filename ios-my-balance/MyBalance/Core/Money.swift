import Foundation

struct CurrencyInfo: Identifiable, Hashable {
    let code: String
    let name: String
    let symbol: String
    var id: String { code }

    static let all: [CurrencyInfo] = [
        CurrencyInfo(code: "EUR", name: "Euro", symbol: "€"),
        CurrencyInfo(code: "USD", name: "Dólar estadounidense", symbol: "$"),
        CurrencyInfo(code: "GBP", name: "Libra esterlina", symbol: "£"),
        CurrencyInfo(code: "CHF", name: "Franco suizo", symbol: "CHF"),
        CurrencyInfo(code: "SEK", name: "Corona sueca", symbol: "kr"),
        CurrencyInfo(code: "NOK", name: "Corona noruega", symbol: "kr"),
        CurrencyInfo(code: "DKK", name: "Corona danesa", symbol: "kr"),
        CurrencyInfo(code: "PLN", name: "Esloti polaco", symbol: "zł"),
        CurrencyInfo(code: "CZK", name: "Corona checa", symbol: "Kč"),
        CurrencyInfo(code: "HUF", name: "Forinto húngaro", symbol: "Ft"),
        CurrencyInfo(code: "RON", name: "Leu rumano", symbol: "lei"),
        CurrencyInfo(code: "MXN", name: "Peso mexicano", symbol: "MX$"),
        CurrencyInfo(code: "ARS", name: "Peso argentino", symbol: "AR$"),
        CurrencyInfo(code: "COP", name: "Peso colombiano", symbol: "COL$"),
        CurrencyInfo(code: "CLP", name: "Peso chileno", symbol: "CLP$"),
        CurrencyInfo(code: "CAD", name: "Dólar canadiense", symbol: "CA$"),
        CurrencyInfo(code: "AUD", name: "Dólar australiano", symbol: "AU$"),
        CurrencyInfo(code: "JPY", name: "Yen japonés", symbol: "¥"),
    ]

    static func find(_ code: String) -> CurrencyInfo {
        all.first { $0.code == code } ?? all[0]
    }
}

/// All money is stored as integer cents. Formatting is done manually to
/// guarantee Spanish (Spain) style: 1.234,56 €
enum Money {
    static var symbol: String = "€"

    enum SignStyle { case auto, always, never }

    static func plain(_ magnitude: UInt) -> String {
        let units = magnitude / 100
        let dec = magnitude % 100
        let digits = String(units)
        var grouped = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && (digits.count - i) % 3 == 0 { grouped.append(".") }
            grouped.append(ch)
        }
        let decStr = dec < 10 ? "0\(dec)" : "\(dec)"
        return grouped + "," + decStr
    }

    static func format(_ cents: Int, sign: SignStyle = .auto) -> String {
        let core = plain(cents.magnitude)
        let prefix: String
        switch sign {
        case .auto: prefix = cents < 0 ? "-" : ""
        case .always: prefix = cents < 0 ? "-" : (cents > 0 ? "+" : "")
        case .never: prefix = ""
        }
        return "\(prefix)\(core) \(symbol)"
    }

    /// Compact label for chart axes: 1,2 k / 3,4 M
    static func compact(_ value: Double) -> String {
        let a = abs(value)
        let sign = value < 0 ? "-" : ""
        if a >= 1_000_000 {
            return sign + String(format: "%.1f M", a / 1_000_000).replacingOccurrences(of: ".", with: ",")
        } else if a >= 1_000 {
            return sign + String(format: "%.1f k", a / 1_000).replacingOccurrences(of: ".", with: ",")
        }
        return sign + String(format: "%.0f", a)
    }

    /// Editable representation without thousands separators: "1234,50"
    static func editString(_ cents: Int) -> String {
        let m = cents.magnitude
        let dec = m % 100
        let s = "\(m / 100),\(dec < 10 ? "0\(dec)" : "\(dec)")"
        return cents < 0 ? "-" + s : s
    }

    /// Parses user input like "48,20", "1.234,56", "1234.5", "-20" into cents.
    static func parse(_ text: String, allowNegative: Bool = false) -> Int? {
        var s = text.replacingOccurrences(of: symbol, with: "")
        s = s.replacingOccurrences(of: "€", with: "")
        s = String(s.filter { !$0.isWhitespace })
        var negative = false
        if s.hasPrefix("-") || s.hasPrefix("−") {
            negative = true
            s.removeFirst()
        } else if s.hasPrefix("+") {
            s.removeFirst()
        }
        guard !s.isEmpty else { return nil }

        var intPart: String
        var fracPart = ""
        if let comma = s.lastIndex(of: ",") {
            intPart = String(s[..<comma]).replacingOccurrences(of: ".", with: "")
            fracPart = String(s[s.index(after: comma)...])
        } else if let dot = s.lastIndex(of: ".") {
            let after = s[s.index(after: dot)...]
            let dotCount = s.filter { $0 == "." }.count
            if dotCount == 1 && after.count <= 2 {
                intPart = String(s[..<dot])
                fracPart = String(after)
            } else {
                intPart = s.replacingOccurrences(of: ".", with: "")
            }
        } else {
            intPart = s
        }
        if intPart.isEmpty { intPart = "0" }

        let isDigit: (Character) -> Bool = { $0.isASCII && $0.isNumber }
        guard intPart.allSatisfy(isDigit), fracPart.allSatisfy(isDigit),
              fracPart.count <= 2, intPart.count <= 11,
              let units = Int(intPart) else { return nil }
        let frac: Int
        switch fracPart.count {
        case 0: frac = 0
        case 1: frac = (Int(fracPart) ?? 0) * 10
        default: frac = Int(fracPart) ?? 0
        }
        var cents = units * 100 + frac
        if negative {
            guard allowNegative else { return nil }
            cents = -cents
        }
        return cents
    }
}

enum Fmt {
    static let es = Locale(identifier: "es_ES")

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = es
        f.dateFormat = "dd/MM/yyyy"
        return f
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = es
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = es
        f.dateFormat = "EEEE"
        return f
    }()

    private static let fileFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = es
        f.dateFormat = "dd-MM-yyyy"
        return f
    }()

    static func date(_ d: Date) -> String { dayFormatter.string(from: d) }
    static func fileDate(_ d: Date) -> String { fileFormatter.string(from: d) }

    static func monthYear(_ d: Date) -> String {
        monthYearFormatter.string(from: d).capitalizedFirst
    }

    static func dayHeader(_ d: Date) -> String {
        let cal = Calendar.app
        if cal.isDateInToday(d) { return "Hoy" }
        if cal.isDateInYesterday(d) { return "Ayer" }
        return "\(weekdayFormatter.string(from: d).capitalizedFirst) · \(date(d))"
    }

    static func percent(_ value: Double, decimals: Int = 1, sign: Bool = false) -> String {
        let pct = value * 100
        var s = String(format: "%.\(decimals)f", abs(pct)).replacingOccurrences(of: ".", with: ",")
        if sign { s = (pct < 0 ? "-" : "+") + s } else if pct < 0 { s = "-" + s }
        return s + " %"
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }

    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Calendar & dates

extension Calendar {
    static let app: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_ES")
        c.firstWeekday = 2
        c.timeZone = .current
        return c
    }()
}

extension Date {
    var startOfDay: Date { Calendar.app.startOfDay(for: self) }

    var startOfMonth: Date {
        Calendar.app.date(from: Calendar.app.dateComponents([.year, .month], from: self)) ?? self
    }

    var startOfNextMonth: Date { startOfMonth.addingMonths(1) }

    var startOfYear: Date {
        Calendar.app.date(from: Calendar.app.dateComponents([.year], from: self)) ?? self
    }

    var startOfWeek: Date {
        Calendar.app.dateInterval(of: .weekOfYear, for: self)?.start ?? startOfDay
    }

    func addingMonths(_ n: Int) -> Date {
        Calendar.app.date(byAdding: .month, value: n, to: self) ?? self
    }

    func addingDays(_ n: Int) -> Date {
        Calendar.app.date(byAdding: .day, value: n, to: self) ?? self
    }

    func addingYears(_ n: Int) -> Date {
        Calendar.app.date(byAdding: .year, value: n, to: self) ?? self
    }
}
