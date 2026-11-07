import SwiftUI
import LocalAuthentication

@Observable
final class AppSettings {
    enum Keys {
        static let name = "userName"
        static let appearance = "appearance"
        static let theme = "themeID"
        static let currency = "currencyCode"
        static let lock = "lockEnabled"
        static let onboarded = "hasOnboarded"
        static let logos = "showBankLogos"
    }

    private let defaults = UserDefaults.standard

    var userName: String { didSet { defaults.set(userName, forKey: Keys.name) } }
    var appearance: AppearanceMode { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    var themeID: String { didSet { defaults.set(themeID, forKey: Keys.theme) } }
    var currencyCode: String {
        didSet {
            defaults.set(currencyCode, forKey: Keys.currency)
            Money.symbol = CurrencyInfo.find(currencyCode).symbol
        }
    }
    var lockEnabled: Bool { didSet { defaults.set(lockEnabled, forKey: Keys.lock) } }
    var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: Keys.onboarded) } }
    var showBankLogos: Bool { didSet { defaults.set(showBankLogos, forKey: Keys.logos) } }
    var accountBalancesVisible = true

    init() {
        let d = UserDefaults.standard
        userName = d.string(forKey: Keys.name) ?? ""
        appearance = AppearanceMode(rawValue: d.string(forKey: Keys.appearance) ?? "") ?? .light
        themeID = d.string(forKey: Keys.theme) ?? "electric"
        let code = d.string(forKey: Keys.currency) ?? "EUR"
        currencyCode = code
        lockEnabled = d.bool(forKey: Keys.lock)
        hasOnboarded = d.bool(forKey: Keys.onboarded)
        showBankLogos = d.object(forKey: Keys.logos) as? Bool ?? true
        Money.symbol = CurrencyInfo.find(code).symbol
    }

    var theme: AppTheme { AppTheme.find(themeID) }
    var currency: CurrencyInfo { CurrencyInfo.find(currencyCode) }

    func resetProfile() {
        userName = ""
        lockEnabled = false
        hasOnboarded = false
    }
}

enum AppTab: Hashable, CaseIterable {
    case home, accounts, movements, stats, budgets, settings

    var title: String {
        switch self {
        case .home: "Inicio"
        case .accounts: "Cuentas"
        case .movements: "Movimientos"
        case .stats: "Estadísticas"
        case .budgets: "Presupuestos"
        case .settings: "Ajustes"
        }
    }

    var compactTitle: String {
        switch self {
        case .movements: "Movs."
        case .stats: "Stats"
        case .budgets: "Presup."
        default: title
        }
    }

    var symbol: String {
        switch self {
        case .home: "house.fill"
        case .accounts: "building.columns.fill"
        case .movements: "tray.full.fill"
        case .stats: "chart.pie.fill"
        case .budgets: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}

@Observable
final class AppRouter {
    var tab: AppTab = .home
}

@Observable
final class LockManager {
    var isLocked: Bool
    var isAuthenticating = false

    init() {
        isLocked = UserDefaults.standard.bool(forKey: AppSettings.Keys.lock)
    }

    struct Availability {
        let available: Bool
        let label: String
    }

    func availability() -> Availability {
        let ctx = LAContext()
        var error: NSError?
        let ok = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        let label: String
        switch ctx.biometryType {
        case .faceID: label = "Face ID"
        case .touchID: label = "Touch ID"
        case .opticID: label = "Optic ID"
        default: label = "código del iPhone"
        }
        return Availability(available: ok, label: label)
    }

    func authenticate(reason: String) async -> Bool {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancelar"
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }

    func unlock() async {
        guard isLocked, !isAuthenticating else { return }
        isAuthenticating = true
        let ok = await authenticate(reason: "Desbloquea la app para ver tus finanzas")
        isAuthenticating = false
        if ok {
            withAnimation(.easeOut(duration: 0.25)) { isLocked = false }
        }
    }
}
