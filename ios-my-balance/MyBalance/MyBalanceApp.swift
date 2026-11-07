import SwiftUI
import SwiftData
import AppIntents

@main
struct MyBalanceApp: App {
    let container: ModelContainer
    @State private var settings: AppSettings
    @State private var router: AppRouter
    @State private var lockManager: LockManager
    @State private var errorCenter: AppErrorCenter

    @MainActor
    init() {
        let modelContainer: ModelContainer
        do {
            modelContainer = try ModelContainer(
                for: Account.self, MovementCategory.self, Movement.self, Budget.self, RecurringRule.self
            )
        } catch {
            fatalError("No se pudo iniciar la base de datos: \(error)")
        }
        container = modelContainer
        let s = AppSettings()
        settings = s
        let appRouter = AppRouter()
        _router = State(initialValue: appRouter)
        let appLockManager = LockManager()
        _lockManager = State(initialValue: appLockManager)
        let errorCenter = AppErrorCenter()
        _errorCenter = State(initialValue: errorCenter)

        // Construct the dependency before passing it to AppDependencyManager.
        // add(dependency:) takes an autoclosure; constructing it inline while
        // reading App properties can capture the mutating initializer's self.
        let shortcutStore = ShortcutFinanceStore(
            container: modelContainer,
            settings: s,
            router: appRouter,
            lockManager: appLockManager
        )
        AppDependencyManager.shared.add(dependency: shortcutStore)
        MyBalanceAppShortcuts.updateAppShortcutParameters()

        // Seed default categories on first launch.
        let context = container.mainContext
        do {
            try Seed.ensureCategories(context)
        } catch {
            errorCenter.message = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(settings)
                .environment(router)
                .environment(lockManager)
                .environment(errorCenter)
                .environment(\.palette, Palette.make(theme: settings.theme, dark: settings.appearance == .dark))
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

/// Tab bar + lock gate + onboarding.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(LockManager.self) private var lockManager
    @Environment(AppErrorCenter.self) private var errorCenter
    @Environment(\.palette) private var palette
    @Query(sort: \Movement.date, order: .reverse) private var movements: [Movement]
    @Query private var budgets: [Budget]
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]
    @Query(sort: \RecurringRule.nextOccurrence) private var recurringRules: [RecurringRule]
    @State private var reviewRuleID: UUID?

    private var localFeatureSignature: String {
        let movementValues = movements.map {
            "\($0.id.uuidString):\($0.amountCents):\($0.date.timeIntervalSince1970):\($0.kindRaw):\($0.isExcluded):\($0.categoryID?.uuidString ?? "")"
        }.joined(separator: "|")
        let budgetValues = budgets.map { "\($0.id.uuidString):\($0.categoryID.uuidString):\($0.limitCents)" }.joined(separator: "|")
        let categoryValues = categories.map { "\($0.id.uuidString):\($0.name):\($0.colorHex):\($0.kindRaw)" }.joined(separator: "|")
        let ruleValues = recurringRules.map { "\($0.id.uuidString):\($0.nextOccurrence.timeIntervalSince1970):\($0.isActive)" }.joined(separator: "|")
        return [movementValues, budgetValues, categoryValues, ruleValues, String(settings.notificationsEnabled), String(settings.dailyReminderEnabled), String(settings.dailyReminderHour), String(settings.dailyReminderMinute), String(settings.budgetAlert80), String(settings.budgetAlert100), String(settings.budgetAlertOver), String(settings.hasOnboarded), String(lockManager.isLocked), settings.currencyCode].joined(separator: "#")
    }

    var body: some View {
        @Bindable var router = router

        ZStack {
            TabView(selection: $router.tab) {
                HomeView()
                    .tabItem { Label("Inicio", systemImage: "house.fill") }
                    .tag(AppTab.home)
                MovementsTab()
                    .tabItem { Label("Movimientos", systemImage: "tray.full.fill") }
                    .tag(AppTab.movements)
                BudgetsTab()
                    .tabItem { Label("Presupuestos", systemImage: "chart.bar.fill") }
                    .tag(AppTab.budgets)
                StatsTab()
                    .tabItem { Label("Estadísticas", systemImage: "chart.pie.fill") }
                    .tag(AppTab.stats)
                AccountsTab()
                    .tabItem { Label("Cuentas", systemImage: "building.columns.fill") }
                    .tag(AppTab.accounts)
            }
            .tint(palette.accent)
            .task { await refreshLocalFeatures() }
            .onChange(of: localFeatureSignature) { _, _ in
                Task { await refreshLocalFeatures() }
            }
            .sheet(isPresented: Binding(
                get: { reviewRuleID != nil },
                set: { if !$0 { reviewRuleID = nil } }
            ), onDismiss: { reviewRuleID = nil }) {
                if let id = reviewRuleID, let rule = recurringRules.first(where: { $0.id == id }) {
                    RecurringReviewView(rule: rule)
                }
            }

            if !settings.hasOnboarded {
                OnboardingView()
                    .transition(.opacity)
                    .zIndex(2)
            } else if lockManager.isLocked {
                LockScreenView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .alert("No se pudo guardar", isPresented: Binding(
            get: { errorCenter.message != nil },
            set: { if !$0 { errorCenter.message = nil } }
        )) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(errorCenter.message ?? "")
        }
        .animation(.easeOut(duration: 0.25), value: lockManager.isLocked)
        .animation(.easeOut(duration: 0.25), value: settings.hasOnboarded)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, settings.lockEnabled {
                lockManager.isLocked = true
            }
            if phase == .active {
                Task {
                    await refreshLocalFeatures()
                }
            }
        }
    }

    @MainActor
    private func refreshLocalFeatures() async {
        await AppNotifications.refresh(
            settings: settings,
            movements: movements,
            budgets: budgets,
            categories: categories,
            recurringRules: recurringRules
        )
        guard settings.hasOnboarded, !lockManager.isLocked, reviewRuleID == nil else { return }
        reviewRuleID = recurringRules.first(where: { rule in
            guard rule.isActive, rule.nextOccurrence <= .now else { return false }
            return rule.endDate.map { rule.nextOccurrence <= $0 } ?? true
        })?.id
    }

}
