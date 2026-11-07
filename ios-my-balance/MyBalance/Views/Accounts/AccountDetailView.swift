import SwiftUI
import SwiftData
import Charts

struct AccountDetailView: View {
    let account: Account

    @Environment(\.palette) private var palette
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @Query(sort: \Movement.date, order: .reverse) private var allMovements: [Movement]
    @Query private var categories: [MovementCategory]

    @State private var showEdit = false
    @State private var showNewMovement = false
    @State private var confirmDelete = false
    @State private var editing: Movement?
    @State private var isGone = false

    private var movements: [Movement] {
        allMovements.filter { $0.accountID == account.id || $0.toAccountID == account.id }
    }

    var body: some View {
        Group {
            if isGone {
                Color.clear.onAppear { dismiss() }
            } else {
                content
            }
        }
    }

    private var content: some View {
        let lookup = Lookup(accounts: [account], categories: categories)
        let balance = Finance.balance(of: account, in: allMovements)
        let monthStart = Date().startOfMonth
        let monthNet = movements
            .filter { $0.date >= monthStart && !$0.isExcluded && $0.kind != .transfer }
            .reduce(0) { $0 + Finance.effect(of: $1, on: account.id) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(
                    balance: balance,
                    monthNet: monthNet,
                    showMonth: movements.contains { $0.date >= monthStart && !$0.isExcluded && $0.kind != .transfer },
                    hideBalance: !settings.accountBalancesVisible
                )

                HStack(spacing: 10) {
                    Button { showNewMovement = true } label: {
                        Label("Nuevo movimiento", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(palette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(palette.accent)
                    }
                    .buttonStyle(PressableStyle())
                    Button { showEdit = true } label: {
                        Label("Editar", systemImage: "pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                }

                if let bank = account.bank {
                    HStack(spacing: 12) {
                        AccountBadge(bankID: bank.id, colorHex: bank.colorHex, symbol: account.iconName, size: 36)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bank.name).font(.subheadline.weight(.semibold))
                            Text(bank.country).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .card(padding: 14)
                }

                movementList(lookup)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(palette.canvas)
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showEdit = true } label: { Label("Editar cuenta", systemImage: "pencil") }
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Eliminar cuenta", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showEdit) { AccountFormView(account: account) }
        .sheet(isPresented: $showNewMovement) {
            MovementFormView(movement: nil, presetAccountID: account.id)
        }
        .sheet(item: $editing) { MovementFormView(movement: $0) }
        .confirmationDialog("¿Eliminar la cuenta?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar cuenta", role: .destructive) {
                withAnimation {
                    AccountActions.delete(account, movements: allMovements, context: context)
                    isGone = true
                }
            }
        } message: {
            Text(AccountActions.deleteMessage(account, movements: allMovements))
        }
        .onDisappear { if isGone { dismiss() } }
    }

    private func header(balance: Int, monthNet: Int, showMonth: Bool, hideBalance: Bool) -> some View {
        let dark = HexColor.prefersDarkText(account.colorHex)
        let base = Color(hex: account.colorHex)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                AccountBadge(account: account, size: 44, inverted: true)
                Spacer()
                Text(account.type.label)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((dark ? Color.black : Color.white).opacity(0.18), in: Capsule())
            }
            Text("Saldo actual")
                .font(.caption.weight(.medium))
                .opacity(0.8)
            Text(hideBalance ? Money.masked : Money.format(balance))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel(hideBalance ? "Saldo actual oculto" : Money.format(balance))
            if hideBalance {
                Text("Saldo inicial oculto")
                    .font(.caption)
                    .opacity(0.75)
            } else {
                Text("Saldo inicial: \(Money.format(account.initialBalanceCents)) · \(Fmt.date(account.initialDate))")
                    .font(.caption)
                    .opacity(0.75)
            }
            if showMonth && !hideBalance {
                let up = monthNet >= 0
                HStack(spacing: 6) {
                    Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption.weight(.bold))
                    Text(Money.format(monthNet, sign: .always))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                    Text("este mes")
                        .font(.subheadline)
                        .opacity(0.75)
                }
            }
            if account.isArchived {
                Label("Cuenta archivada", systemImage: "archivebox")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.2), in: Capsule())
            }
        }
        .foregroundStyle(dark ? Color.black.opacity(0.85) : .white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(colors: [base, base.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle().fill(.white.opacity(0.1)).frame(width: 160, height: 160).offset(x: 50, y: -60)
                }
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    private func movementList(_ lookup: Lookup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Movimientos")
            if movements.isEmpty {
                Text("No hay movimientos en esta cuenta todavía.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                let grouped = Dictionary(grouping: movements) { $0.date.startOfDay }
                let days = grouped.keys.sorted().reversed()
                VStack(spacing: 14) {
                    ForEach(Array(days.enumerated()), id: \.element) { _, day in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Fmt.dayHeader(day))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 4)
                            ForEach(grouped[day]!.sorted { $0.date > $1.date }) { m in
                                Button { editing = m } label: {
                                    MovementRow(movement: m, lookup: lookup, relativeTo: account.id, showDate: false)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(PressableStyle())
                                .foregroundStyle(.primary)
                                Divider().padding(.leading, 54)
                            }
                        }
                    }
                }
                .card(padding: 16)
            }
        }
    }
}
