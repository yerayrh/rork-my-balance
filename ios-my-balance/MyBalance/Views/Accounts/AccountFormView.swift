import SwiftUI
import SwiftData

struct AccountFormView: View {
    /// `nil` crea una cuenta nueva; si no, edita la existente.
    let account: Account?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @Query private var accounts: [Account]
    @Query private var allMovements: [Movement]

    @State private var name = ""
    @State private var bankID: String?
    @State private var colorHex = HexColor.swatches[0]
    @State private var iconName = AccountType.checking.defaultIcon
    @State private var type: AccountType = .checking
    @State private var balanceText = ""
    @State private var initialDate = Date().startOfDay
    @State private var isArchived = false
    @State private var showBankPicker = false
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var saveError: String?

    private var isEditing: Bool { account != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        AccountBadge(bankID: bankID, colorHex: colorHex, symbol: iconName, size: 52)
                        TextField("Nombre de la cuenta", text: $name)
                            .font(.headline)
                            .textInputAutocapitalization(.sentences)
                    }
                    .listRowBackground(palette.surface)
                }

                Section("Tipo de cuenta") {
                    Picker("Tipo", selection: $type) {
                        ForEach(AccountType.allCases) { t in
                            Label(t.label, systemImage: t.defaultIcon).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .listRowBackground(palette.surface)
                }

                Section("Banco") {
                    Button { showBankPicker = true } label: {
                        HStack {
                            if let bank = bankID.flatMap({ BankCatalog.byID[$0] }) {
                                AccountBadge(bankID: bank.id, colorHex: bank.colorHex, symbol: "", size: 32)
                                Text(bank.name).foregroundStyle(.primary)
                                Spacer()
                                Text(bank.country).font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Elegir banco")
                                    .foregroundStyle(palette.accent)
                                Spacer()
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if bankID != nil {
                        Button(role: .destructive) {
                            bankID = nil
                            colorHex = HexColor.swatches[0]
                        } label: {
                            Label("Quitar banco", systemImage: "xmark.circle")
                                .font(.subheadline)
                        }
                    }
                }
                .listRowBackground(palette.surface)

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 9), spacing: 10) {
                        ForEach(HexColor.swatches, id: \.self) { hex in
                            Button {
                                colorHex = hex
                                bankID = nil
                            } label: {
                                ZStack {
                                    Circle().fill(Color(hex: hex)).frame(width: 34, height: 34)
                                    if colorHex == hex && bankID == nil {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.heavy))
                                            .foregroundStyle(HexColor.prefersDarkText(hex) ? .black.opacity(0.8) : .white)
                                    }
                                }
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Color \(hex)")
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(palette.surface)

                Section {
                    HStack {
                        Text("Saldo inicial")
                        Spacer()
                        TextField("0,00", text: $balanceText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: 140)
                    }
                    DatePicker("Fecha del saldo inicial", selection: $initialDate, displayedComponents: .date)
                } header: {
                    Text("Saldo inicial")
                } footer: {
                    Text("El saldo de hoy se calcula sumando a esta cantidad los movimientos desde la fecha indicada.")
                }
                .listRowBackground(palette.surface)

                if isEditing {
                    Section {
                        Toggle("Archivar cuenta", isOn: $isArchived)
                    } footer: {
                        Text("Las cuentas archivadas no se cuentan en el dinero total y quedan al final de la lista.")
                    }
                    .listRowBackground(palette.surface)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Editar cuenta" : "Nueva cuenta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .sheet(isPresented: $showBankPicker) {
                BankPickerView(selectedID: $bankID,currentColor: colorHex)
            }
            .onChange(of: bankID) {
                if let bank = bankID.flatMap({ BankCatalog.byID[$0] }) {
                    colorHex = bank.colorHex
                }
            }
            .onAppear(perform: load)
            .toolbar {
                if isEditing {
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Label("Eliminar cuenta", systemImage: "trash")
                        }
                        .confirmationDialog("¿Eliminar la cuenta?", isPresented: $confirmDelete, titleVisibility: .visible) {
                            Button("Eliminar cuenta", role: .destructive) {
                                guard let account else { return }
                                do {
                                    try AccountActions.delete(account, movements: allMovements, context: context)
                                    dismiss()
                                } catch {
                                    saveError = error.localizedDescription
                                }
                            }
                        } message: {
                            Text(account.map { AccountActions.deleteMessage($0, movements: allMovements) } ?? "")
                        }
                    }
                }
            }
            .alert("No se pudo guardar", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(nil)
    }

    private var isValid: Bool {
        !name.trimmed.isEmpty && Money.parse(balanceText) != nil
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let account else { return }
        name = account.name
        bankID = account.bankID
        colorHex = account.colorHex
        iconName = account.iconName
        type = account.type
        balanceText = Money.editString(account.initialBalanceCents)
        initialDate = account.initialDate
        isArchived = account.isArchived
    }

    private func save() {
        guard let cents = Money.parse(balanceText) else { return }
        let finalColor = bankID != nil ? (BankCatalog.byID[bankID ?? ""]?.colorHex ?? colorHex) : colorHex
        do {
            if let account {
                account.name = name.trimmed
                account.bankID = bankID
                account.colorHex = finalColor
                account.iconName = type.defaultIcon
                account.type = type
                account.initialBalanceCents = cents
                account.initialDate = initialDate
                account.isArchived = isArchived
                try context.save()
            } else {
                let a = Account(
                    name: name.trimmed,
                    bankID: bankID,
                    colorHex: finalColor,
                    iconName: type.defaultIcon,
                    type: type,
                    initialBalanceCents: cents,
                    initialDate: initialDate,
                    sortOrder: (accounts.map(\.sortOrder).max() ?? 0) + 1
                )
                context.insert(a)
                try context.save()
            }
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}
