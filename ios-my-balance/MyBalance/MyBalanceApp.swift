import SwiftUI
import SwiftData

@main
struct MyBalanceApp: App {
    let container: ModelContainer
    @State private var settings: AppSettings
    @State private var router = AppRouter()
    @State private var lockManager = LockManager()

    init() {
        do {
            container = try ModelContainer(
                for: Account.self, MovementCategory.self, Movement.self, Budget.self
            )
        } catch {
            fatalError("No se pudo iniciar la base de datos: \(error)")
        }
        let s = AppSettings()
        settings = s

        // Seed default categories on first launch.
        let context = container.mainContext
        Seed.ensureCategories(context)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .environment(settings)
                .environment(router)
                .environment(lockManager)
                .environment(\.palette, Palette.make(theme: settings.theme, dark: settings.appearance == .dark))
                .preferredColorScheme(settings.appearance.colorScheme)
        }
    }
}

/// Tab bar + lock gate + onboarding.
struct RootView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(LockManager.self) private var lockManager
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var router = router

        ZStack {
            TabView(selection: $router.tab) {
                HomeView()
                    .tabItem { Label("Inicio", systemImage: "house.fill") }
                    .tag(AppTab.home)
                AccountsTab()
                    .tabItem { Label("Cuentas", systemImage: "building.columns.fill") }
                    .tag(AppTab.accounts)
                MovementsTab()
                    .tabItem { Label("Movimientos", systemImage: "tray.full.fill") }
                    .tag(AppTab.movements)
                StatsTab()
                    .tabItem { Label("Estadísticas", systemImage: "chart.pie.fill") }
                    .tag(AppTab.stats)
                SettingsTab()
                    .tabItem { Label("Ajustes", systemImage: "gearshape.fill") }
                    .tag(AppTab.settings)
            }
            .tint(palette.accent)

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
        .animation(.easeOut(duration: 0.25), value: lockManager.isLocked)
        .animation(.easeOut(duration: 0.25), value: settings.hasOnboarded)
    }
}
