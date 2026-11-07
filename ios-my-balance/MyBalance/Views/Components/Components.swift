import SwiftUI

struct CardBackground: ViewModifier {
    @Environment(\.palette) private var palette
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardBackground(padding: padding)) }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension String {
    /// Category icons are either SF Symbol names (ASCII) or a user-picked emoji.
    var isEmojiIcon: Bool { !isEmpty && !allSatisfy(\.isASCII) }
}

struct IconBadge: View {
    let symbol: String
    let colorHex: String
    var size: CGFloat = 40

    var body: some View {
        let c = Color(hex: colorHex)
        if symbol.isEmojiIcon {
            Circle()
                .fill(c)
                .frame(width: size, height: size)
                .overlay {
                    Text(symbol).font(.system(size: size * 0.5))
                }
        } else {
            Circle()
                .fill(c.opacity(0.16))
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: size * 0.42, weight: .semibold))
                        .foregroundStyle(c)
                }
        }
    }
}

/// Small inline icon for a category: emoji text or SF Symbol.
struct CategoryGlyph: View {
    let icon: String
    var body: some View {
        if icon.isEmojiIcon {
            Text(icon).font(.subheadline)
        } else {
            Image(systemName: icon).font(.caption.weight(.bold))
        }
    }
}

struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
            }
        }
    }
}

struct MonthSelector: View {
    @Binding var month: Date
    @Environment(\.palette) private var palette

    var body: some View {
        HStack {
            Button {
                withAnimation(.snappy) { month = month.addingMonths(-1) }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(palette.surface, in: Circle())
            }
            .accessibilityLabel("Mes anterior")
            Spacer()
            Text(Fmt.monthYear(month))
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            Button {
                withAnimation(.snappy) { month = month.addingMonths(1) }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(palette.surface, in: Circle())
            }
            .accessibilityLabel("Mes siguiente")
        }
        .foregroundStyle(.primary)
        .sensoryFeedback(.selection, trigger: month)
    }
}

struct Chip: View {
    let title: String
    var symbol: String? = nil
    let selected: Bool
    let action: () -> Void
    @Environment(\.palette) private var palette

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol).font(.caption.weight(.semibold)) }
                Text(title).font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? palette.onAccent : Color.primary)
            .background(selected ? palette.accent : palette.surface, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.selection, trigger: selected)
    }
}

struct ExcludedTag: View {
    var body: some View {
        Text("Excluido")
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Color(hex: "#E67E00"))
            .background(Color(hex: "#FF9F0A").opacity(0.16), in: Capsule())
    }
}

struct DemoTag: View {
    var body: some View {
        Text("Demo")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(.secondary)
            .background(Color.secondary.opacity(0.15), in: Capsule())
    }
}

struct EmptyCard: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 60, height: 60)
                .background(palette.accent.opacity(0.12), in: Circle())
            Text(title).font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .card(padding: 22)
    }
}

struct MetricTile: View {
    let title: String
    let cents: Int
    let symbol: String
    let tint: Color
    var sign: Money.SignStyle = .auto
    var footnote: String? = nil
    /// Soft tinted background: pass the pale light-mode hex (e.g. #EAFAF4 / #FDEFF6).
    var fillHex: String? = nil

    @Environment(\.palette) private var palette
    @Environment(\.colorScheme) private var scheme

    private var background: Color {
        guard let fillHex else { return palette.surface }
        return scheme == .dark ? tint.opacity(0.18) : Color(hex: fillHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(fillHex != nil ? tint.opacity(0.16) : tint.opacity(0.15), in: Circle())
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(Money.format(cents, sign: sign))
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.snappy(duration: 0.25), value: cents >= 0)
    }
}

/// Floating action button used on the home tab.
struct FloatingAddButton: View {
    let action: () -> Void
    @Environment(\.palette) private var palette
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(palette.onAccent)
                .frame(width: 60, height: 60)
                .background(palette.accent, in: Circle())
                .shadow(color: palette.accent.opacity(0.4), radius: 14, y: 6)
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel("Nuevo movimiento")
    }
}
