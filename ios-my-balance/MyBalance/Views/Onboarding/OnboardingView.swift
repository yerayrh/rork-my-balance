import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(AppSettings.self) private var settings

    @State private var page = 0
    @State private var name = ""
    @State private var wantsDemo = true

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                namePage.tag(1)
                themePage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < 2 {
                    withAnimation(.snappy(duration: 0.3)) { page += 1 }
                } else {
                    finish()
                }
            } label: {
                Text(page < 2 ? "Continuar" : "Empezar a usarla")
                    .font(.headline)
                    .foregroundStyle(palette.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(palette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

            if page > 0 {
                Button("Saltar") { finish() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
            }
        }
        .background(palette.canvas)
    }

    private func finish() {
        settings.userName = name.trimmed
        if wantsDemo {
            Seed.loadDemo(context)
        }
        settings.hasOnboarded = true
    }

    // MARK: Pages

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(palette.accent.opacity(0.12)).frame(width: 130, height: 130)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
            VStack(spacing: 10) {
                Text("Tus cuentas, tus números")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Controla tus bancos, tarjetas y efectivo en una sola app. Sin cuentas de usuario: todo se queda en tu iPhone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            Spacer()
        }
        .padding(24)
    }

    private var namePage: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(palette.accent.opacity(0.12)).frame(width: 130, height: 130)
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 52, weight: .semibold))
                    .foregroundStyle(palette.accent)
            }
            VStack(spacing: 10) {
                Text("¿Cómo te llamamos?")
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text("Es opcional. Solo lo usamos para darte la bienvenida.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            TextField("Tu nombre (opcional)", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .textInputAutocapitalization(.sentences)
                .padding(.horizontal, 12)
            Spacer()
        }
        .padding(24)
    }

    private var themePage: some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text("Elige tu color")
                    .font(.largeTitle.weight(.bold))
                Text("Puedes cambiarlo cuando quieras en Ajustes.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(AppTheme.all) { theme in
                    let accent = Color(hex: theme.accentLight)
                    Button {
                        withAnimation(.snappy(duration: 0.25)) { settings.themeID = theme.id }
                    } label: {
                        ZStack {
                            Circle().fill(accent).frame(width: 44, height: 44)
                            if settings.themeID == theme.id {
                                Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 2).frame(width: 52, height: 52)
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(HexColor.prefersDarkText(theme.accentLight) ? Color.black.opacity(0.8) : .white)
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Tema \(theme.name)")
                }
            }
            .padding(.horizontal, 12)

            Toggle(isOn: $wantsDemo) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ver la app con datos de ejemplo")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .toggleStyle(.switch)
            .tint(palette.accent)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer()
        }
        .padding(24)
    }
}

// MARK: - Lock screen

struct LockScreenView: View {
    @Environment(LockManager.self) private var lockManager
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                ZStack {
                    Circle().fill(palette.accent.opacity(0.12)).frame(width: 110, height: 110)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(palette.accent)
                }
                VStack(spacing: 8) {
                    Text("App bloqueada")
                        .font(.title2.weight(.bold))
                    Text("Tus finanzas están protegidas.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    Task { await lockManager.unlock() }
                } label: {
                    Label("Desbloquear", systemImage: "faceid")
                        .font(.headline)
                        .foregroundStyle(palette.onAccent)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(palette.accent, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(lockManager.isAuthenticating)
                Spacer()
                Spacer()
            }
            .padding(24)
        }
        .onAppear {
            Task { await lockManager.unlock() }
        }
    }
}
