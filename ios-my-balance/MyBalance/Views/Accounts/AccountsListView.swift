import SwiftUI
import SwiftData

struct AccountsTab: View {
    var body: some View {
        NavigationStack {
            AccountsListView()
        }
    }
}

struct AccountsListView: View {
    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Account.sortOrder) private var accounts: [Account]
    @Query private var movements: [Movement]

    @State private var showNew = false
    @State private var editing: Account?
    @State private var pendingDelete: Account?

    var body: some View {
        let active = accounts.filter { !$0.isArchived }
        let archived = accounts.filter(\.isArchived)
        let balances = Finance.balances(accounts, movements)
        let total = active.reduce(0) { $0 + (balances[$1.id] ?? 0) }

        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Saldo total")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(settings.accountBalancesVisible ? Money.format(total) : Money.masked)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .accessibilityLabel(settings.accountBalancesVisible ? Money.format(total) : "Saldo total oculto")
                    Text(active.count == 1 ? "1 cuenta activa" : "\(active.count) cuentas activas")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 6)

                if accounts.isEmpty {
                    EmptyCard(symbol: "building.columns.fill", title: "Sin cuentas", message: "Crea tantas cuentas como necesites: bancos, tarjetas, ahorro o efectivo.", actionTitle: "Añadir cuenta") {
                        showNew = true
                    }
                }

                ForEach(active) { a in
                    row(a, balance: balances[a.id] ?? 0)
                }

                if !archived.isEmpty {
                    Text("Archivadas")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 10)
                    ForEach(archived) { a in
                        row(a, balance: balances[a.id] ?? 0)
                    }
                }

                if !accounts.isEmpty {
                    Button { showNew = true } label: {
                        Label("Añadir cuenta", systemImage: "plus")
                            .font(.headline)
                            .foregroundStyle(palette.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .strokeBorder(palette.accent.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                            }
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(palette.canvas)
        .navigationTitle("Cuentas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showNew = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Nueva cuenta")
            }
        }
        .sheet(isPresented: $showNew) { AccountFormView(account: nil) }
        .sheet(item: $editing) { AccountFormView(account: $0) }
        .confirmationDialog(
            "¿Eliminar la cuenta?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { a in
            Button("Eliminar cuenta", role: .destructive) {
                withAnimation { AccountActions.delete(a, movements: movements, context: context) }
            }
        } message: { a in
            Text(AccountActions.deleteMessage(a, movements: movements))
        }
    }

    private func row(_ a: Account, balance: Int) -> some View {
        NavigationLink {
            AccountDetailView(account: a)
        } label: {
            AccountWideCard(account: a, balance: balance, hideBalance: !settings.accountBalancesVisible)
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button { editing = a } label: { Label("Editar", systemImage: "pencil") }
            Button(role: .destructive) { pendingDelete = a } label: { Label("Eliminar", systemImage: "trash") }
        }
    }
}

enum AccountActions {
    static func related(_ a: Account, movements: [Movement]) -> [Movement] {
        movements.filter { $0.accountID == a.id || $0.toAccountID == a.id }
    }

    static func deleteMessage(_ a: Account, movements: [Movement]) -> String {
        let n = related(a, movements: movements).count
        if n == 0 { return "Se eliminará «\(a.name)». Esta acción no se puede deshacer." }
        return "Se eliminará «\(a.name)» junto con sus \(n) movimientos (incluidas las transferencias). Esta acción no se puede deshacer."
    }

    static func delete(_ a: Account, movements: [Movement], context: ModelContext) {
        for m in related(a, movements: movements) { context.delete(m) }
        context.delete(a)
        try? context.save()
    }
}
