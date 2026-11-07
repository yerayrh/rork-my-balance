import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme

    @Environment(AppSettings.self) private var settings
    @Environment(LockManager.self) private var lockManager
    @Environment(AppErrorCenter.self) private var errorCenter

    @Query private var accounts: [Account]
    @Query private var movements: [Movement]
    @Query private var categories: [MovementCategory]
    @Query private var budgets: [Budget]
    @Query(sort: \RecurringRule.nextOccurrence) private var recurringRules: [RecurringRule]

    @State private var editingName = ""
    @State private var showCSVExporter = false
    @State private var showRestoreImporter = false
    @State private var exportText = ""
    @State private var exportFilename = "mybalance-exportacion"
    @State private var restoreError: String?
    @State private var exportError: String?
    @State private var restoreSummary: RestoreSummary?
    @State private var confirmWipe = false
    @State private var confirmRemoveDemo = false
    @State private var confirmLoadDemo = false
    @State private var showNotificationsExplanation = false
    @State private var showNotificationsDenied = false
    @State private var notificationTestMessage: String?

    var body: some View {
        Form {
            profileSection
            appearanceSection
            categoriesSection
            currencySection
            securitySection
            notificationsSection
            recurringSection
            dataSection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(palette.canvas)
        .navigationTitle("Ajustes")
        .onAppear { editingName = settings.userName }
        .fileExporter(
            isPresented: $showCSVExporter,
            document: CSVDocument(text: exportText),
            contentType: .commaSeparatedText,
            defaultFilename: exportFilename
        ) { result in
            if case .failure(let error) = result {
                exportError = error.localizedDescription
            }
        }
        .fileImporter(
            isPresented: $showRestoreImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText]
        ) { result in
            restore(from: result)
        }
        .alert("No se pudo restaurar", isPresented: Binding(get: { restoreError != nil }, set: { if !$0 { restoreError = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(restoreError ?? "")
        }
        .alert("No se pudo exportar", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .alert("Copia restaurada", isPresented: Binding(get: { restoreSummary != nil }, set: { if !$0 { restoreSummary = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            if let s = restoreSummary {
                Text("Se han restaurado \(s.accounts) cuentas, \(s.categories) categorías, \(s.movements) movimientos, \(s.budgets) presupuestos y \(s.recurringRules) reglas recurrentes.")
            }
        }
        .alert("Notificaciones de My Balance", isPresented: $showNotificationsExplanation) {
            Button("Continuar") { requestNotifications() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("My Balance usará notificaciones locales para los avisos de presupuesto, movimientos recurrentes y el recordatorio diario que configures. No se envían datos a un servidor.")
        }
        .alert("Notificaciones no permitidas", isPresented: $showNotificationsDenied) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Puedes permitirlas en Ajustes del iPhone > Notificaciones > My Balance.")
        }
        .alert("Prueba de notificación", isPresented: Binding(
            get: { notificationTestMessage != nil },
            set: { if !$0 { notificationTestMessage = nil } }
        )) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(notificationTestMessage ?? "")
        }
    }

    // MARK: Sections

    private var profileSection: some View {
        Section {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(palette.accent)
                TextField("Tu nombre", text: $editingName)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
            }
        } header: {
            Text("Perfil")
        } footer: {
            Text("Se usa para saludarte en la pantalla de inicio.")
        }
        .onChange(of: editingName) { settings.userName = editingName.trimmed }
    }

    private var appearanceSection: some View {
        Section {
            Picker("Modo", selection: Binding(
                get: { settings.appearance },
                set: { settings.appearance = $0 }
            )) {
                ForEach(AppearanceMode.allCases) { m in
                    Text(m.label).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            themeGrid
        } header: {
            Text("Apariencia")
        } footer: {
            Text("El color se aplica a botones, gráficas y detalles en toda la app.")
        }
    }

    private var themeGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
            ForEach(AppTheme.all) { theme in
                let dark = colorScheme == .dark
                let accent = Color(hex: dark ? theme.accentDark : theme.accentLight)
                Button {
                    withAnimation(.snappy(duration: 0.25)) { settings.themeID = theme.id }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(accent).frame(width: 38, height: 38)
                            if settings.themeID == theme.id {
                                Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 2).frame(width: 46, height: 46)
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(HexColor.prefersDarkText(dark ? theme.accentDark : theme.accentLight) ? Color.black.opacity(0.8) : .white)
                            }
                        }
                        Text(theme.name)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(PressableStyle())
                .sensoryFeedback(.selection, trigger: settings.themeID == theme.id)
                .accessibilityLabel("Tema \(theme.name)")
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }

    private var categoriesSection: some View {
        let expense = categories.filter { $0.kind == .expense }.count
        let income = categories.filter { $0.kind == .income }.count
        return Section {
            NavigationLink {
                CategoriesView()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.onAccent)
                        .frame(width: 30, height: 30)
                        .background(palette.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Gestionar categorías")
                        Text("\(expense) de gasto · \(income) de ingreso")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Categorías")
        } footer: {
            Text("Crea, edita, ordena o elimina las categorías de gastos e ingresos.")
        }
    }

    private var currencySection: some View {
        Section {
            Picker("Moneda", selection: Binding(
                get: { settings.currencyCode },
                set: { settings.currencyCode = $0 }
            )) {
                ForEach(CurrencyInfo.all) { c in
                    Text("\(c.name) (\(c.symbol))").tag(c.code)
                }
            }
        } header: {
            Text("Moneda")
        } footer: {
            Text("Solo cambia cómo se muestran los importes; no se hacen conversiones.")
        }
    }

    private var securitySection: some View {
        Section {
            if lockManager.availability().available {
                Toggle("Bloquear con \(lockManager.availability().label)", isOn: Binding(
                        get: { settings.lockEnabled },
                        set: { newValue in
                            settings.lockEnabled = newValue
                            lockManager.isLocked = newValue
                        }
                    )
                )
            } else {
                Label("El bloqueo no está disponible en este dispositivo", systemImage: "lock.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Toggle("Mostrar logos de bancos", isOn: Binding(
                get: { settings.showBankLogos },
                set: { settings.showBankLogos = $0 }
            ))
        } header: {
            Text("Seguridad y privacidad")
        } footer: {
            Text("Todos los datos viven solo en este dispositivo. Nada se envía a ningún servidor.")
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Activar notificaciones", isOn: Binding(
                get: { settings.notificationsEnabled },
                set: { enabled in
                    if enabled {
                        showNotificationsExplanation = true
                    } else {
                        settings.notificationsEnabled = false
                        Task { await AppNotifications.cancelAll() }
                    }
                }
            ))
            if settings.notificationsEnabled {
                Toggle("Recordatorio diario de movimientos", isOn: Binding(
                    get: { settings.dailyReminderEnabled },
                    set: { settings.dailyReminderEnabled = $0 }
                ))
                if settings.dailyReminderEnabled {
                    DatePicker(
                        "Hora del recordatorio",
                        selection: dailyReminderTime,
                        displayedComponents: .hourAndMinute
                    )
                }
                Button {
                    Task {
                        do {
                            try await AppNotifications.sendTestNotification()
                            notificationTestMessage = "Notificación enviada. Si no aparece en pantalla, revisa los permisos y los avisos en Ajustes del iPhone > Notificaciones > My Balance."
                        } catch {
                            notificationTestMessage = error.localizedDescription
                        }
                    }
                } label: {
                    Label("Enviar notificación de prueba", systemImage: "bell.badge")
                }
                Toggle("Al alcanzar el 80 %", isOn: Binding(
                    get: { settings.budgetAlert80 },
                    set: { settings.budgetAlert80 = $0 }
                ))
                Toggle("Al alcanzar el 100 %", isOn: Binding(
                    get: { settings.budgetAlert100 },
                    set: { settings.budgetAlert100 = $0 }
                ))
                Toggle("Al superar el presupuesto", isOn: Binding(
                    get: { settings.budgetAlertOver },
                    set: { settings.budgetAlertOver = $0 }
                ))
            }
        } header: {
            Text("Notificaciones")
        } footer: {
            Text("Los avisos y el recordatorio diario se programan en este iPhone. No se envían datos a servidores.")
        }
    }

    private var dailyReminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.app.date(
                    bySettingHour: settings.dailyReminderHour,
                    minute: settings.dailyReminderMinute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let components = Calendar.app.dateComponents([.hour, .minute], from: date)
                settings.dailyReminderHour = components.hour ?? 20
                settings.dailyReminderMinute = components.minute ?? 0
            }
        )
    }

    private var recurringSection: some View {
        Section {
            NavigationLink {
                RecurringRulesView()
            } label: {
                HStack {
                    Label("Movimientos recurrentes", systemImage: "repeat")
                    Spacer()
                    Text("\(recurringRules.filter(\.isActive).count)")
                        .foregroundStyle(.secondary)
                }
            }
            if movements.contains(where: { $0.isRecurring && $0.recurringRuleID == nil }) {
                Text("Los movimientos antiguos marcados como recurrentes se conservan, pero no generan futuros cargos automáticamente.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Programación")
        }
    }

    private var dataSection: some View {
        let demoCount = accounts.filter(\.isDemo).count
        return Section {
            Button {
                exportText = Backup.makeBackup(
                    accounts: accounts,
                    categories: categories,
                    movements: movements,
                    budgets: budgets,
                    recurringRules: recurringRules,
                    settings: settings
                )
                exportFilename = "mybalance-copia-seguridad"
                showCSVExporter = true
            } label: {
                Label("Exportar copia de seguridad", systemImage: "square.and.arrow.up")
            }

            Button {
                showRestoreImporter = true
            } label: {
                Label("Restaurar copia de seguridad", systemImage: "square.and.arrow.down")
            }

            if demoCount > 0 {
                Button(role: .destructive) {
                    confirmRemoveDemo = true
                } label: {
                    Label("Eliminar datos de demostración", systemImage: "sparkles")
                }
                .confirmationDialog("¿Eliminar los datos de demostración?", isPresented: $confirmRemoveDemo, titleVisibility: .visible) {
                    Button("Eliminar datos de demostración", role: .destructive) {
                        do { try Seed.removeDemo(context) }
                        catch { errorCenter.message = error.localizedDescription }
                    }
                } message: {
                    Text("Se borrarán las cuentas, movimientos y presupuestos marcados como demo. Tus datos reales no se tocan.")
                }
            } else {
                Button {
                    confirmLoadDemo = true
                } label: {
                    Label("Cargar datos de ejemplo", systemImage: "sparkles")
                }
                .confirmationDialog("¿Cargar datos de ejemplo?", isPresented: $confirmLoadDemo, titleVisibility: .visible) {
                    Button("Cargar datos de ejemplo") {
                        do { try Seed.loadDemo(context) }
                        catch { errorCenter.message = error.localizedDescription }
                    }
                } message: {
                    Text("Se añadirán cuentas y movimientos de ejemplo (marcados como demo). Podrás borrarlos en cualquier momento.")
                }
            }

            Button(role: .destructive) {
                confirmWipe = true
            } label: {
                Label("Borrar todos los datos", systemImage: "trash")
            }
            .confirmationDialog("¿Borrar todos los datos?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Borrar todo", role: .destructive) {
                    do {
                        try Seed.wipeAll(context)
                        UserDefaults.standard.set(false, forKey: Seed.seededKey)
                        try Seed.ensureCategories(context)
                    } catch {
                        errorCenter.message = error.localizedDescription
                    }
                }
            } message: {
                Text("Se eliminarán cuentas, categorías, movimientos, presupuestos y reglas recurrentes. Después se restaurarán las categorías básicas. Esta acción no se puede deshacer.")
            }
        } header: {
            Text("Copia de seguridad y datos")
        } footer: {
            Text("La copia de seguridad incluye cuentas, movimientos, presupuestos y reglas recurrentes. También se pueden restaurar copias antiguas. Restaurarla sustituye lo que hay ahora en la app.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Versión", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.1.0")
            LabeledContent("Datos guardados", value: "En este iPhone")
        } header: {
            Text("Acerca de")
        } footer: {
            HStack(spacing: 4) {
                Text("Made by Yeray & Iván with")
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Restore

    private func requestNotifications() {
        Task {
            let allowed = await AppNotifications.requestPermission()
            settings.notificationsEnabled = allowed
            if !allowed { showNotificationsDenied = true }
        }
    }

    private func restore(from result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            restoreError = error.localizedDescription
        case .success(let url):
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                restoreSummary = try Backup.restore(text, context: context, settings: settings)
            } catch {
                restoreError = (error as? BackupError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
