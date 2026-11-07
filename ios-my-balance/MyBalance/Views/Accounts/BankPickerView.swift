import SwiftUI

/// Hoja «Elegir banco»: catálogo europeo agrupado por país, con buscador.
/// La hoja lleva siempre el título «Elegir banco» — nunca el nombre de la app.
struct BankPickerView: View {
    @Binding var selectedID: String?
    var currentColor: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var query = ""
    @State private var picked: String?

    private var filtered: [(String, [Bank])] {
        let q = query.trimmed.lowercased()
        let groups = Dictionary(grouping: BankCatalog.all, by: \.country)
        return BankCatalog.countries.compactMap { country in
            guard let banks = groups[country] else { return nil }
            let list = q.isEmpty
                ? banks
                : banks.filter { $0.name.lowercased().contains(q) || country.lowercased().contains(q) }
            return list.isEmpty ? nil : (country, list)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedID = nil
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.secondary.opacity(0.18))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            Text("Sin banco (solo color e icono)")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedID == nil {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(palette.accent)
                            }
                        }
                    }
                }

                ForEach(filtered, id: \.0) { country, banks in
                    Section(country) {
                        ForEach(banks) { bank in
                            Button {
                                selectedID = bank.id
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    AccountBadge(bankID: bank.id, colorHex: bank.colorHex, symbol: "", size: 36)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bank.name)
                                            .foregroundStyle(.primary)
                                            .font(.subheadline.weight(.semibold))
                                        Text(bank.domain)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedID == bank.id {
                                        Image(systemName: "checkmark")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(palette.accent)
                                    }
                                }
                            }
                        }
                    }
                }

                if filtered.isEmpty {
                    Section {
                        Text("No hay bancos que coincidan con «\(query)».")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Elegir banco")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar banco o país")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
