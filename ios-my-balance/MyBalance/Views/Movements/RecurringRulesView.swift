import SwiftUI
import SwiftData

struct RecurringRulesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Query(sort: \RecurringRule.nextOccurrence) private var rules: [RecurringRule]
    @Query private var accounts: [Account]
    @State private var saveError: String?

    var body: some View {
        List {
            if rules.isEmpty {
                ContentUnavailableView(
                    "Sin movimientos recurrentes",
                    systemImage: "repeat",
                    description: Text("Al crear un movimiento, activa la opción Repetir movimiento para programarlo.")
                )
            } else {
                ForEach(rules) { rule in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.title.isEmpty ? rule.kind.label : rule.title)
                                .font(.subheadline.weight(.semibold))
                            Text("\(rule.frequency.label) · \(accountName(rule.accountID))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Siguiente: \(Fmt.date(rule.nextOccurrence)) · \(Money.format(rule.amountCents))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 4)
                        Toggle("Activa", isOn: Binding(
                            get: { rule.isActive },
                            set: { value in
                                rule.isActive = value
                                save()
                            }
                        ))
                        .labelsHidden()
                        .tint(palette.accent)
                        .accessibilityLabel(rule.isActive ? "Desactivar recurrencia" : "Activar recurrencia")
                    }
                    .padding(.vertical, 4)
                    .swipeActions {
                        Button(role: .destructive) {
                            context.delete(rule)
                            save()
                        } label: {
                            Label("Eliminar", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(palette.canvas)
        .navigationTitle("Movimientos recurrentes")
        .alert("No se pudo guardar", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private func accountName(_ id: UUID) -> String {
        accounts.first(where: { $0.id == id })?.name ?? "Cuenta eliminada"
    }

    private func save() {
        do {
            try context.save()
        } catch {
            context.rollback()
            saveError = error.localizedDescription
        }
    }
}
