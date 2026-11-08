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
        static let notifications = "notificationsEnabled"
        static let dailyReminder = "dailyEntryReminderEnabled"
        static let dailyReminderHour = "dailyEntryReminderHour"
        static let dailyReminderMinute = "dailyEntryReminderMinute"
        static let balancesVisible = "accountBalancesVisible"
        static let budgetAlert80 = "budgetAlert80"
        static let budgetAlert100 = "budgetAlert100"
        static let budgetAlertOver = "budgetAlertOver"
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
    var accountBalancesVisible: Bool { didSet { defaults.set(accountBalancesVisible, forKey: Keys.balancesVisible) } }
    var notificationsEnabled: Bool { didSet { defaults.set(notificationsEnabled, forKey: Keys.notifications) } }
    var dailyReminderEnabled: Bool { didSet { defaults.set(dailyReminderEnabled, forKey: Keys.dailyReminder) } }
    var dailyReminderHour: Int { didSet { defaults.set(dailyReminderHour, forKey: Keys.dailyReminderHour) } }
    var dailyReminderMinute: Int { didSet { defaults.set(dailyReminderMinute, forKey: Keys.dailyReminderMinute) } }
    var budgetAlert80: Bool { didSet { defaults.set(budgetAlert80, forKey: Keys.budgetAlert80) } }
    var budgetAlert100: Bool { didSet { defaults.set(budgetAlert100, forKey: Keys.budgetAlert100) } }
    var budgetAlertOver: Bool { didSet { defaults.set(budgetAlertOver, forKey: Keys.budgetAlertOver) } }

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
        accountBalancesVisible = d.object(forKey: Keys.balancesVisible) as? Bool ?? true
        notificationsEnabled = d.object(forKey: Keys.notifications) as? Bool ?? false
        dailyReminderEnabled = d.object(forKey: Keys.dailyReminder) as? Bool ?? false
        dailyReminderHour = d.object(forKey: Keys.dailyReminderHour) as? Int ?? 20
        dailyReminderMinute = d.object(forKey: Keys.dailyReminderMinute) as? Int ?? 0
        budgetAlert80 = d.object(forKey: Keys.budgetAlert80) as? Bool ?? true
        budgetAlert100 = d.object(forKey: Keys.budgetAlert100) as? Bool ?? true
        budgetAlertOver = d.object(forKey: Keys.budgetAlertOver) as? Bool ?? false
        Money.symbol = CurrencyInfo.find(code).symbol
    }

    var theme: AppTheme { AppTheme.find(themeID) }
    var currency: CurrencyInfo { CurrencyInfo.find(currencyCode) }
}

enum AppTab: Hashable {
    case home, accounts, movements, stats, budgets
}

@Observable
final class AppRouter {
    var tab: AppTab = .home
}

@Observable
final class AppErrorCenter {
    var message: String?
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
