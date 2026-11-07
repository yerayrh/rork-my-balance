import SwiftUI
import SwiftData

/// Sheet to create a custom category with an icon (or any emoji) and a colour.
struct CategoryFormView: View {
    let kind: CategoryKind
    /// When set, the form edits this category instead of creating a new one.
    var category: MovementCategory? = nil
    var onCreate: (MovementCategory) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]

    @State private var name = ""
    @State private var icon = "tag.fill"
    @State private var colorHex = "#2F5BFF"
    @State private var customColor = Color(hex: "#2F5BFF")
    @State private var emojiFocused = false
    @State private var loaded = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { category != nil }

    private var isCustomColor: Bool { !Self.colors.contains(colorHex) }
    private var isCustomEmoji: Bool { icon.isEmojiIcon }

    /// Same saturated swatches used across the app (accounts, themes).
    static let colors: [String] = HexColor.swatches

    /// SF Symbols in the same style as the built-in categories.
    static let icons: [String] = [
        "tag.fill", "bag.fill", "cart.fill", "fork.knife", "cup.and.saucer.fill", "wineglass.fill", "carrot.fill", "birthday.cake.fill",
        "house.fill", "lightbulb.fill", "bolt.fill", "drop.fill", "wifi", "phone.fill", "wrench.and.screwdriver.fill", "sofa.fill",
        "car.fill", "fuelpump.fill", "bus.fill", "tram.fill", "airplane", "bicycle", "beach.umbrella.fill", "bed.double.fill",
        "cross.case.fill", "pills.fill", "heart.fill", "figure.run", "dumbbell.fill", "scissors", "tshirt.fill", "stroller.fill",
        "gamecontroller.fill", "film.fill", "music.note", "book.fill", "graduationcap.fill", "pawprint.fill", "gift.fill", "theatermasks.fill",
        "iphone", "laptopcomputer", "tv.fill", "doc.text.fill", "building.columns.fill", "creditcard.fill", "banknote.fill", "briefcase.fill",
        "chart.line.uptrend.xyaxis", "eurosign.circle.fill", "percent", "leaf.fill", "globe.europe.africa.fill", "star.fill", "sparkles", "ellipsis.circle.fill"
    ]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isDuplicate: Bool {
        categories.contains { $0.id != category?.id && $0.kind == kind && $0.name.compare(trimmedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    private var isValid: Bool { !trimmedName.isEmpty && !isDuplicate }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Button {
                            nameFocused = false
                            emojiFocused = true
                        } label: {
                            IconBadge(symbol: icon, colorHex: colorHex, size: 84)
                                .shadow(color: Color(hex: colorHex).opacity(0.5), radius: 12, y: 6)
                                .overlay(alignment: .bottomTrailing) {
                                    Image(systemName: "pencil")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(palette.onAccent)
                                        .frame(width: 26, height: 26)
                                        .background(palette.accent, in: Circle())
                                        .overlay(Circle().stroke(palette.canvas, lineWidth: 2))
                                }
                                .animation(.snappy(duration: 0.25), value: colorHex)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("Usar un emoji")
                        Text(trimmedName.isEmpty ? (isEditing ? "Sin nombre" : "Nueva categoría") : trimmedName)
                            .font(.headline)
                            .foregroundStyle(trimmedName.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Nombre", text: $name)
                        .textInputAutocapitalization(.sentences)
                        .focused($nameFocused)
                        .submitLabel(.done)
                    if isDuplicate && !trimmedName.isEmpty {
                        Label("Ya existe una categoría con ese nombre", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(palette.negative)
                    }
                } header: {
                    Text(kind == .income ? "Categoría de ingreso" : "Categoría de gasto")
                }
                .listRowBackground(palette.surface)

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 9), spacing: 10) {
                        ForEach(Self.colors, id: \.self) { hex in
                            Button {
                                withAnimation(.snappy(duration: 0.2)) { colorHex = hex }
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 30, height: 30)
                                    .overlay {
                                        if colorHex == hex {
                                            Circle().stroke(Color.primary.opacity(0.8), lineWidth: 2.5).padding(-4)
                                        }
                                    }
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel("Color \(hex)")
                        }
                    }
                    .padding(.vertical, 6)
                    .sensoryFeedback(.selection, trigger: colorHex)

                    HStack(spacing: 12) {
                        Circle()
                            .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
                            .frame(width: 28, height: 28)
                            .overlay {
                                if isCustomColor {
                                    Circle().fill(Color(hex: colorHex)).padding(5)
                                }
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Color personalizado")
                                .font(.subheadline.weight(.medium))
                            Text(isCustomColor ? colorHex : "Elige cualquier color")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ColorPicker("Color personalizado", selection: $customColor, supportsOpacity: false)
                            .labelsHidden()
                    }
                }
                .listRowBackground(palette.surface)

                Section {
                    Button {
                        nameFocused = false
                        emojiFocused = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "face.smiling")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(palette.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Cualquier emoji")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(emojiFocused ? "Elige uno en el teclado" : "Abre el teclado de emojis")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if isCustomEmoji {
                                Text(icon).font(.title2)
                            }
                            Image(systemName: "keyboard")
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background {
                        EmojiTextField(emoji: $icon, isFocused: $emojiFocused)
                            .frame(width: 1, height: 1)
                            .opacity(0.01)
                            .accessibilityHidden(true)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 10) {
                        ForEach(Self.icons, id: \.self) { name in
                            let selected = icon == name
                            let c = Color(hex: colorHex)
                            Button {
                                withAnimation(.snappy(duration: 0.2)) { icon = name }
                            } label: {
                                Image(systemName: name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(selected ? Color.white : c)
                                    .frame(width: 38, height: 38)
                                    .background(selected ? c : c.opacity(0.14), in: Circle())
                                    .scaleEffect(selected ? 1.08 : 1)
                            }
                            .buttonStyle(PressableStyle())
                            .accessibilityLabel(name)
                        }
                    }
                    .padding(.vertical, 6)
                    .sensoryFeedback(.selection, trigger: icon)
                } header: {
                    Text("Icono")
                } footer: {
                    Text("Elige un icono o toca «Cualquier emoji» para usar el que quieras desde el teclado.")
                }
                .listRowBackground(palette.surface)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isEditing ? "Editar categoría" : "Nueva categoría")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Guardar" : "Crear") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onAppear {
                guard !loaded else { return }
                loaded = true
                if let category {
                    name = category.name
                    icon = category.icon
                    colorHex = category.colorHex.uppercased()
                    customColor = Color(hex: category.colorHex)
                } else {
                    nameFocused = true
                }
            }
            .onChange(of: nameFocused) { _, focused in
                if focused { emojiFocused = false }
            }
            .onChange(of: customColor) { _, newValue in
                withAnimation(.snappy(duration: 0.2)) { colorHex = newValue.hexString }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func save() {
        guard isValid else { return }
        if let category {
            category.name = trimmedName
            category.icon = icon
            category.colorHex = colorHex
            try? context.save()
            onCreate(category)
            dismiss()
            return
        }
        let order = (categories.filter { $0.kind == kind }.map(\.sortOrder).max() ?? 0) + 1
        let c = MovementCategory(name: trimmedName, icon: icon, colorHex: colorHex, kind: kind, sortOrder: order, isDefault: false)
        context.insert(c)
        try? context.save()
        onCreate(c)
        dismiss()
    }
}
