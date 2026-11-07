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
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Environment(AppRouter.self) private var router
    @Environment(LockManager.self) private var lockManager
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var router = router

        ZStack {
            Group {
                HomeView().tabContent(isActive: router.tab == .home)
                AccountsTab().tabContent(isActive: router.tab == .accounts)
                MovementsTab().tabContent(isActive: router.tab == .movements)
                StatsTab().tabContent(isActive: router.tab == .stats)
                BudgetsTab().tabContent(isActive: router.tab == .budgets)
                SettingsTab().tabContent(isActive: router.tab == .settings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if settings.hasOnboarded && !lockManager.isLocked {
                    RootTabBar(selection: $router.tab, tint: palette.accent, surface: palette.surface)
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
        .animation(.easeOut(duration: 0.25), value: lockManager.isLocked)
        .animation(.easeOut(duration: 0.25), value: settings.hasOnboarded)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background, settings.lockEnabled {
                lockManager.isLocked = true
            }
        }
    }
}

private extension View {
    func tabContent(isActive: Bool) -> some View {
        opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }
}

private struct RootTabBar: View {
    @Binding var selection: AppTab
    let tint: Color
    let surface: Color

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                let selected = selection == tab
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: selected ? .semibold : .regular))
                            .frame(height: 21)
                        Text(tab.compactTitle)
                            .font(.system(size: 9, weight: selected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .foregroundStyle(selected ? tint : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .background {
            surface
                .overlay(alignment: .top) { Color.primary.opacity(0.07).frame(height: 0.5) }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
