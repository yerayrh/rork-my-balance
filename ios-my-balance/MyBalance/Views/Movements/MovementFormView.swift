import SwiftUI
import SwiftData

struct MovementFormView: View {
    /// `nil` crea un movimiento nuevo; si no, edita el existente.
    let movement: Movement?
    var presetAccountID: UUID? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]

    @State private var kind: MovementKind = .expense
    @State private var amountText = ""
    @State private var title = ""
    @State private var notes = ""
    @State private var date = Date()
    @State private var accountID: UUID?
    @State private var toAccountID: UUID?
    @State private var categoryID: UUID?
    @State private var isExcluded = false
    @State private var isRecurring = false
    @State private var recurrenceFrequency: RecurrenceFrequency = .monthly
    @State private var hasRecurrenceEndDate = false
    @State private var recurrenceEndDate = Date().addingMonths(12)
    @State private var confirmDelete = false
    @State private var loaded = false
    @State private var showNewCategory = false
    @State private var categoryToDelete: MovementCategory?
    @State private var saveError: String?

    private var isEditing: Bool { movement != nil }

    private var visibleCategories: [MovementCategory] {
        categories.filter { $0.kind.rawValue == (kind == .income ? "income" : "expense") }
    }

    private var parsedAmount: Int? {
        Money.parse(amountText, allowNegative: kind != .income)
    }

    private var isValid: Bool {
        guard let cents = parsedAmount, cents > 0 else { return false }
        guard let accountID else { return false }
        if kind == .transfer && toAccountID == nil { return false }
        if kind == .transfer && toAccountID == accountID { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                kindSection
                amountSection
                if kind != .transfer { categorySection }
                accountSection
                detailSection
                if isEditing { flagsSection }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editTitle)
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
            .confirmationDialog(
                "¿Eliminar la categoría «\(categoryToDelete?.name ?? "")»?",
                isPresented: Binding(get: { categoryToDelete != nil }, set: { if !$0 { categoryToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Eliminar categoría", role: .destructive) { deleteCategory() }
            } message: {
                Text("Los movimientos que la usen quedarán sin categoría.")
            }
            .sheet(isPresented: $showNewCategory) {
                CategoryFormView(kind: kind == .income ? .income : .expense) { c in
                    withAnimation(.snappy(duration: 0.2)) { categoryID = c.id }
                }
            }
            .onAppear(perform: load)
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
    }

    private var editTitle: String {
        if let movement {
            switch movement.kind {
            case .expense: "Editar gasto"
            case .income: "Editar ingreso"
            case .transfer: "Editar transferencia"
            }
        } else {
            switch kind {
            case .expense: "Nuevo gasto"
            case .income: "Nuevo ingreso"
            case .transfer: "Nueva transferencia"
            }
        }
    }

    private var kindSection: some View {
        Section {
            Picker("Tipo", selection: Binding(
                get: { kind },
                set: { newValue in
                    withAnimation(.snappy(duration: 0.25)) {
                        kind = newValue
                        categoryID = nil
                        if newValue == .transfer { isRecurring = false }
                    }
                }
            )) {
                ForEach([MovementKind.expense, .income, .transfer]) { k in
                    Text(k.label).tag(k)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.horizontal, 4)
        }
    }

    private var amountSection: some View {
        Section {
            HStack(spacing: 8) {
                TextField("0,00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .monospacedDigit()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            TextField(kind == .transfer ? "Concepto (opcional)" : "Concepto", text: $title)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .listRowBackground(palette.surface)
        }
    }

    private var categorySection: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(visibleCategories) { c in
                        Button {
                            withAnimation(.snappy(duration: 0.2)) {
                                categoryID = categoryID == c.id ? nil : c.id
                            }
                        } label: {
                            categoryChip(c, selected: categoryID == c.id)
                        }
                        .buttonStyle(PressableStyle())
                        .sensoryFeedback(.selection, trigger: categoryID == c.id)
                        .contextMenu {
                            if !c.isDefault {
                                Button("Eliminar categoría", systemImage: "trash", role: .destructive) {
                                    categoryToDelete = c
                                }
                            }
                        }
                    }

                    Button { showNewCategory = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.caption.weight(.bold))
                            Text("Nueva").font(.subheadline.weight(.semibold))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(palette.accent)
                        .background {
                            Capsule().strokeBorder(palette.accent.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("Crear categoría")
                }
                .scrollTargetLayout()
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Categoría (opcional)")
        }
    }

    @ViewBuilder
    private func categoryChip(_ c: MovementCategory, selected: Bool) -> some View {
        let color = Color(hex: c.colorHex)
        let label = HStack(spacing: 6) {
            CategoryGlyph(icon: c.icon)
            Text(c.name).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        if c.icon.isEmojiIcon {
            // Custom category: pastel background chosen by the user, readable dark text.
            label
                .foregroundStyle(selected ? (HexColor.luminance(c.colorHex) > 0.6 ? Color.black.opacity(0.85) : Color.white) : Color.primary)
                .background(color.opacity(selected ? 1 : 0.35), in: Capsule())
                .overlay {
                    if selected { Capsule().strokeBorder(Color.primary.opacity(0.7), lineWidth: 1.5) }
                }
        } else {
            label
                .foregroundStyle(selected ? palette.onAccent : color)
                .background(selected ? color : color.opacity(0.14), in: Capsule())
        }
    }

    private func deleteCategory() {
        guard let c = categoryToDelete else { return }
        do {
            let id = c.id
            let all = try context.fetch(FetchDescriptor<Movement>())
            for m in all where m.categoryID == id { m.categoryID = nil }
            if categoryID == id { categoryID = nil }
            context.delete(c)
            try context.save()
            categoryToDelete = nil
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }

    private var accountSection: some View {
        Section(kind == .transfer ? "Cuentas" : "Cuenta") {
            Picker("Cuenta origen", selection: $accountID) {
                ForEach(accounts) { a in
                    Text(a.name).tag(UUID?.some(a.id))
                }
            }
            if kind == .transfer {
                Picker("Cuenta destino", selection: $toAccountID) {
                    Text("Elegir…").tag(UUID?.none)
                    ForEach(accounts.filter { $0.id != accountID }) { a in
                        Text(a.name).tag(UUID?.some(a.id))
                    }
                }
                if toAccountID != nil && toAccountID == accountID {
                    Label("Elige una cuenta distinta al origen", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(palette.negative)
                }
            }
        }
        .listRowBackground(palette.surface)
    }

    @ViewBuilder
    private var detailSection: some View {
        Section {
            DatePicker("Fecha", selection: $date, displayedComponents: .date)
            Toggle("Excluir de estadísticas", isOn: $isExcluded)
            if isEditing {
                if movement?.isRecurring == true, movement?.recurringRuleID == nil {
                    Label("Este movimiento tiene una marca recurrente antigua; no programa nuevos movimientos.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if movement?.recurringRuleID != nil {
                    Label("Este movimiento forma parte de una regla recurrente. Gestiona sus próximas fechas desde Ajustes.", systemImage: "repeat.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if kind != .transfer {
                Toggle("Repetir movimiento", isOn: $isRecurring)
                if isRecurring {
                    Picker("Frecuencia", selection: $recurrenceFrequency) {
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Text(frequency.label).tag(frequency)
                        }
                    }
                    Toggle("Fecha de finalización", isOn: $hasRecurrenceEndDate)
                    if hasRecurrenceEndDate {
                        DatePicker("Finaliza el", selection: $recurrenceEndDate, in: date.addingDays(1)..., displayedComponents: .date)
                    }
                }
            }
        } header: {
            Text("Detalles")
        } footer: {
            Text("Los movimientos excluidos se guardan en el saldo de las cuentas, pero no cuentan en estadísticas ni presupuestos.")
        }
        .listRowBackground(palette.surface)

        Section {
            TextField("Notas (opcional)", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        }
        .listRowBackground(palette.surface)
    }

    private var flagsSection: some View {
        Section {
            Button(role: .destructive) { confirmDelete = true } label: {
                Label("Eliminar movimiento", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .confirmationDialog("¿Eliminar el movimiento?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Eliminar movimiento", role: .destructive) {
                    guard let movement else { return }
                    context.delete(movement)
                    do {
                        try context.save()
                        dismiss()
                    } catch {
                        context.rollback()
                        saveError = error.localizedDescription
                    }
                }
            } message: {
                Text("Esta acción no se puede deshacer.")
            }
        }
        .listRowBackground(Color.clear)
    }

    // MARK: Load & save

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let movement {
            kind = movement.kind
            amountText = Money.editString(movement.amountCents)
            title = movement.title
            notes = movement.notes
            date = movement.date
            accountID = movement.accountID
            toAccountID = movement.toAccountID
            categoryID = movement.categoryID
            isExcluded = movement.isExcluded
            isRecurring = movement.isRecurring
        } else {
            date = Date()
            accountID = presetAccountID ?? accounts.first?.id
            toAccountID = nil
            recurrenceEndDate = Date().addingMonths(12)
        }
    }

    private func save() {
        guard let cents = parsedAmount, cents > 0, let accountID else { return }
        if let movement {
            movement.kind = kind
            movement.amountCents = cents
            movement.title = title.trimmed
            movement.notes = notes.trimmed
            movement.date = date
            movement.accountID = accountID
            movement.toAccountID = kind == .transfer ? toAccountID : nil
            movement.categoryID = kind == .transfer ? nil : categoryID
            movement.isExcluded = isExcluded
            movement.isRecurring = isRecurring
            movement.updatedAt = .now
        } else {
            let m = Movement(
                kind: kind,
                amountCents: cents,
                title: title.trimmed,
                notes: notes.trimmed,
                date: date,
                accountID: accountID,
                toAccountID: kind == .transfer ? toAccountID : nil,
                categoryID: kind == .transfer ? nil : categoryID,
                isExcluded: isExcluded,
                isRecurring: false
            )
            if isRecurring, kind != .transfer,
               let nextOccurrence = RecurrenceCalendar.nextDate(after: date, frequency: recurrenceFrequency, anchorDate: date),
               !hasRecurrenceEndDate || nextOccurrence <= recurrenceEndDate {
                let rule = RecurringRule(
                    kind: kind,
                    amountCents: cents,
                    title: title.trimmed,
                    notes: notes.trimmed,
                    accountID: accountID,
                    categoryID: categoryID,
                    isExcluded: isExcluded,
                    frequency: recurrenceFrequency,
                    startDate: date,
                    nextOccurrence: nextOccurrence,
                    endDate: hasRecurrenceEndDate ? recurrenceEndDate : nil,
                    anchorDay: Calendar.app.component(.day, from: date)
                )
                m.isRecurring = true
                m.recurringRuleID = rule.id
                m.recurrenceOccurrence = date
                context.insert(rule)
            }
            context.insert(m)
        }
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}
