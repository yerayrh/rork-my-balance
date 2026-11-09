import SwiftUI
import SwiftData

/// Settings screen to create, edit, reorder and delete expense and income categories.
struct CategoriesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.palette) private var palette
    @Environment(AppErrorCenter.self) private var errorCenter

    @Query(sort: \MovementCategory.sortOrder) private var categories: [MovementCategory]
    @Query private var movements: [Movement]
    @Query private var budgets: [Budget]
    @Query private var recurringRules: [RecurringRule]

    @State private var kind: CategoryKind = .expense
    @State private var showNew = false
    @State private var editing: MovementCategory?
    @State private var toDelete: MovementCategory?
    @State private var confirmRestore = false
    @State private var editMode: EditMode = .inactive

    private var visible: [MovementCategory] {
        categories.filter { $0.kind == kind }
    }

    private var usage: [UUID: Int] {
        var d: [UUID: Int] = [:]
        for m in movements { if let id = m.categoryID { d[id, default: 0] += 1 } }
        return d
    }

    private var missingDefaults: [(String, String, String)] {
        let defaults = kind == .income ? Seed.incomeDefaults : Seed.expenseDefaults
        let names = Set(visible.map { $0.name.lowercased() })
        return defaults.filter { !names.contains($0.0.lowercased()) }
    }

    var body: some View {
        let counts = usage
        List {
            Section {
                Picker("Tipo", selection: $kind.animation(.snappy(duration: 0.25))) {
                    Text("Gastos").tag(CategoryKind.expense)
                    Text("Ingresos").tag(CategoryKind.income)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if visible.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "square.grid.2x2")
                            .font(.title)
                            .foregroundStyle(palette.accent)
                        Text(kind == .income ? "No tienes categorías de ingreso" : "No tienes categorías de gasto")
                            .font(.subheadline.weight(.semibold))
                        Button("Crear categoría") { showNew = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(visible) { c in
                        NavigationLink {
                            CategoryMovementsView(category: c)
                        } label: {
                            row(c, count: counts[c.id] ?? 0)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Eliminar", systemImage: "trash", role: .destructive) { toDelete = c }
                            Button("Editar", systemImage: "pencil") { editing = c }
                                .tint(palette.accent)
                        }
                        .contextMenu {
                            Button("Editar", systemImage: "pencil") { editing = c }
                            Button("Eliminar", systemImage: "trash", role: .destructive) { toDelete = c }
                        }
                    }
                    .onMove(perform: move)
                }
            } header: {
                Text("\(visible.count) \(visible.count == 1 ? "categoría" : "categorías")")
            } footer: {
                Text("Toca una categoría para ver sus movimientos. Desliza a la izquierda o mantén pulsado para editarla o eliminarla; usa «Ordenar» para cambiar el orden.")
            }
            .listRowBackground(palette.surface)

            Section {
                Button { showNew = true } label: {
                    Label(kind == .income ? "Nueva categoría de ingreso" : "Nueva categoría de gasto", systemImage: "plus.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(palette.accent)
                }
                if !missingDefaults.isEmpty {
                    Button { confirmRestore = true } label: {
                        Label("Restaurar categorías predefinidas", systemImage: "arrow.counterclockwise")
                    }
                }
            }
            .listRowBackground(palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(palette.canvas)
        .navigationTitle("Categorías")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !visible.isEmpty {
                    Button(editMode.isEditing ? "Listo" : "Ordenar") {
                        withAnimation(.snappy) { editMode = editMode.isEditing ? .inactive : .active }
                    }
                    .fontWeight(editMode.isEditing ? .semibold : .regular)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nueva categoría")
            }
        }
        .environment(\.editMode, $editMode)
        .onChange(of: kind) { editMode = .inactive }
        .sheet(isPresented: $showNew) {
            CategoryFormView(kind: kind)
        }
        .sheet(item: $editing) { c in
            CategoryFormView(kind: c.kind, category: c)
        }
        .confirmationDialog(
            "¿Eliminar «\(toDelete?.name ?? "")»?",
            isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Eliminar categoría", role: .destructive) { delete() }
        } message: {
            let n = toDelete.map { counts[$0.id] ?? 0 } ?? 0
            let ruleCount = toDelete.map { category in recurringRules.filter { $0.categoryID == category.id }.count } ?? 0
            let budgetCount = toDelete.map { category in budgets.filter { $0.categoryID == category.id }.count } ?? 0
            if n > 0 {
                Text("\(n) \(n == 1 ? "movimiento quedará" : "movimientos quedarán") sin categoría. \(ruleCount) \(ruleCount == 1 ? "regla recurrente perderá" : "reglas recurrentes perderán") la categoría y se eliminarán \(budgetCount) \(budgetCount == 1 ? "presupuesto" : "presupuestos") asociado\(budgetCount == 1 ? "" : "s"). Los saldos no cambian.")
            } else {
                Text("La categoría se quitará de \(ruleCount) \(ruleCount == 1 ? "regla recurrente" : "reglas recurrentes") y se eliminarán \(budgetCount) \(budgetCount == 1 ? "presupuesto" : "presupuestos") asociado\(budgetCount == 1 ? "" : "s").")
            }
        }
        .confirmationDialog("¿Restaurar categorías predefinidas?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restaurar \(missingDefaults.count)") { restoreDefaults() }
        } message: {
            Text("Se volverán a añadir las categorías de serie que hayas eliminado. Tus categorías no se tocan.")
        }
        .sensoryFeedback(.selection, trigger: kind)
    }

    private func row(_ c: MovementCategory, count: Int) -> some View {
        HStack(spacing: 12) {
            IconBadge(symbol: c.icon, colorHex: c.colorHex, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(count == 0 ? "Sin movimientos" : "\(count) \(count == 1 ? "movimiento" : "movimientos")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !c.isDefault {
                Text("Personal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.accent.opacity(0.12), in: Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }

    // MARK: Actions

    private func move(from source: IndexSet, to destination: Int) {
        var items = visible
        items.move(fromOffsets: source, toOffset: destination)
        for (i, c) in items.enumerated() { c.sortOrder = i }
        do { try context.save() }
        catch {
            context.rollback()
            errorCenter.message = error.localizedDescription
        }
    }

    private func delete() {
        guard let c = toDelete else { return }
        let id = c.id
        do {
            withAnimation(.snappy) {
                for m in movements where m.categoryID == id { m.categoryID = nil }
                for rule in recurringRules where rule.categoryID == id { rule.categoryID = nil }
                for b in budgets where b.categoryID == id { context.delete(b) }
                context.delete(c)
            }
            try context.save()
            toDelete = nil
        } catch {
            context.rollback()
            errorCenter.message = error.localizedDescription
        }
    }

    private func restoreDefaults() {
        let start = (visible.map(\.sortOrder).max() ?? -1) + 1
        withAnimation(.snappy) {
            for (i, d) in missingDefaults.enumerated() {
                context.insert(MovementCategory(name: d.0, icon: d.1, colorHex: d.2, kind: kind, sortOrder: start + i, isDefault: true))
            }
        }
        do { try context.save() }
        catch {
            context.rollback()
            errorCenter.message = error.localizedDescription
        }
    }
}
