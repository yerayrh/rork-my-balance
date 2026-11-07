import SwiftUI

/// Bank logo or account icon on a rounded tile.
struct AccountBadge: View {
    let bankID: String?
    let colorHex: String
    let symbol: String
    var size: CGFloat = 40
    /// White tile with brand-coloured content (for use on brand-coloured cards).
    var inverted: Bool = false

    @Environment(AppSettings.self) private var settings

    init(account: Account, size: CGFloat = 40, inverted: Bool = false) {
        self.bankID = account.bankID
        self.colorHex = account.colorHex
        self.symbol = account.iconName
        self.size = size
        self.inverted = inverted
    }

    init(bankID: String?, colorHex: String, symbol: String, size: CGFloat = 40, inverted: Bool = false) {
        self.bankID = bankID
        self.colorHex = colorHex
        self.symbol = symbol
        self.size = size
        self.inverted = inverted
    }

    var body: some View {
        let bank = bankID.flatMap { BankCatalog.byID[$0] }
        let base = Color(hex: colorHex)
        let fg: Color = inverted ? base : (HexColor.prefersDarkText(colorHex) ? Color.black.opacity(0.85) : .white)

        RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(inverted ? Color.white : base)
            .frame(width: size, height: size)
            .overlay {
                if let bank {
                    if settings.showBankLogos, let url = bank.logoURL {
                        AsyncImage(url: url, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                            if case .success(let image) = phase {
                                logo(image)
                            } else {
                                monogram(bank, fg)
                            }
                        }
                    } else {
                        monogram(bank, fg)
                    }
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(fg)
                }
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func logo(_ image: Image) -> some View {
        if inverted {
            image.resizable().interpolation(.high).scaledToFit()
                .frame(width: size * 0.6, height: size * 0.6)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: size * 0.2, style: .continuous)
                .fill(.white)
                .frame(width: size * 0.66, height: size * 0.66)
                .overlay {
                    image.resizable().interpolation(.high).scaledToFit()
                        .frame(width: size * 0.48, height: size * 0.48)
                        .clipShape(RoundedRectangle(cornerRadius: size * 0.08, style: .continuous))
                }
        }
    }

    private func monogram(_ bank: Bank, _ fg: Color) -> some View {
        Text(bank.monogram)
            .font(.system(size: size * (bank.monogram.count > 2 ? 0.26 : 0.36), weight: .heavy, design: .rounded))
            .foregroundStyle(fg)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(size * 0.08)
    }
}

struct MovementRow: View {
    let movement: Movement
    let lookup: Lookup
    var relativeTo: UUID? = nil
    var showDate: Bool = true

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            icon
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(displayTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    if movement.isRecurring {
                        Image(systemName: "repeat")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(amountColor)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    if movement.isExcluded { ExcludedTag() }
                    if showDate {
                        Text(Fmt.date(movement.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
        .opacity(movement.isExcluded ? 0.72 : 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var category: MovementCategory? { lookup.category(movement.categoryID) }

    @ViewBuilder
    private var icon: some View {
        if movement.kind == .transfer {
            Circle()
                .fill(palette.accent.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(palette.accent)
                }
        } else {
            IconBadge(symbol: category?.icon ?? "questionmark", colorHex: category?.colorHex ?? "#94A3B8", size: 42)
        }
    }

    private var displayTitle: String {
        if !movement.title.trimmed.isEmpty { return movement.title }
        if movement.kind == .transfer { return "Transferencia" }
        return category?.name ?? movement.kind.label
    }

    private var subtitle: String {
        if movement.kind == .transfer {
            return "\(lookup.accountName(movement.accountID)) → \(lookup.accountName(movement.toAccountID))"
        }
        return "\(category?.name ?? "Sin categoría") · \(lookup.accountName(movement.accountID))"
    }

    private var amountText: String {
        switch movement.kind {
        case .income: return Money.format(movement.amountCents, sign: .always)
        case .expense: return Money.format(-movement.amountCents)
        case .transfer:
            if let relativeTo {
                if movement.accountID == relativeTo { return Money.format(-movement.amountCents) }
                if movement.toAccountID == relativeTo { return Money.format(movement.amountCents, sign: .always) }
            }
            return Money.format(movement.amountCents)
        }
    }

    private var amountColor: Color {
        switch movement.kind {
        case .income: return palette.positive
        case .expense: return .primary
        case .transfer:
            if let relativeTo, movement.toAccountID == relativeTo { return palette.positive }
            return .secondary
        }
    }
}

struct AccountCard: View {
    let account: Account
    let balance: Int
    var hideBalance = false

    var body: some View {
        let dark = HexColor.prefersDarkText(account.colorHex)
        let base = Color(hex: account.colorHex)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                AccountBadge(account: account, size: 36, inverted: true)
                Spacer()
                Text(account.type.label)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((dark ? Color.black : Color.white).opacity(0.16), in: Capsule())
            }
            Spacer(minLength: 10)
            Text(account.name)
                .font(.subheadline.weight(.medium))
                .opacity(0.85)
                .lineLimit(1)
            Text(hideBalance ? Money.masked : Money.format(balance))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(hideBalance ? "Saldo de la cuenta oculto" : Money.format(balance))
        }
        .foregroundStyle(dark ? Color.black.opacity(0.85) : .white)
        .padding(16)
        .frame(width: 192, height: 132)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [base, base.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(.white.opacity(0.09))
                        .frame(width: 120, height: 120)
                        .offset(x: 40, y: -50)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

struct AccountWideCard: View {
    let account: Account
    let balance: Int
    var hideBalance = false

    var body: some View {
        let dark = HexColor.prefersDarkText(account.colorHex)
        let base = Color(hex: account.colorHex)
        HStack(spacing: 14) {
            AccountBadge(account: account, size: 46, inverted: true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(.headline)
                        .lineLimit(1)
                    if account.isDemo {
                        Text("Demo")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background((dark ? Color.black : Color.white).opacity(0.18), in: Capsule())
                    }
                }
                Text([account.bank?.name, account.type.label].compactMap { $0 }.joined(separator: " · "))
                    .font(.footnote)
                    .opacity(0.8)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(hideBalance ? Money.masked : Money.format(balance))
                .font(.system(.title3, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel(hideBalance ? "Saldo de la cuenta oculto" : Money.format(balance))
        }
        .foregroundStyle(dark ? Color.black.opacity(0.85) : .white)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [base, base.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 140, height: 140)
                        .offset(x: 60)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .opacity(account.isArchived ? 0.6 : 1)
    }
}
