import SwiftUI
import SwiftData

struct RecurringReviewView: View {
    let rule: RecurringRule

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "repeat.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(palette.accent)
                Text("¿Añadir este movimiento?")
                    .font(.title2.weight(.bold))
                Text(rule.title.isEmpty ? rule.kind.label : rule.title)
                    .font(.headline)
                Text(Money.format(rule.amountCents))
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .monospacedDigit()
                Text("Fecha: \(Fmt.date(rule.nextOccurrence)) · \(rule.frequency.label.lowercased())")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("El movimiento solo se guardará si lo confirmas.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(action: confirmOccurrence) {
                    Label("Añadir movimiento", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .disabled(isSaving || !rule.isActive)

                Button("Omitir esta vez", role: .destructive, action: skipOccurrence)
                    .disabled(isSaving || !rule.isActive)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.canvas)
            .navigationTitle("Movimiento recurrente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Más tarde") { dismiss() }
                }
            }
            .alert("No se pudo actualizar", isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text(saveError ?? "")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func confirmOccurrence() {
        guard rule.isActive else { return }
        isSaving = true
        let occurrenceDate = rule.nextOccurrence
        let duplicate = RecurrenceCalendar.alreadyRecorded(
            ruleID: rule.id,
            occurrence: occurrenceDate,
            movements: (try? context.fetch(FetchDescriptor<Movement>())) ?? []
        )
        guard !duplicate else {
            advanceRule()
            return
        }

        context.insert(Movement(
            kind: rule.kind,
            amountCents: rule.amountCents,
            title: rule.title,
            notes: rule.notes,
            date: occurrenceDate,
            accountID: rule.accountID,
            categoryID: rule.categoryID,
            isExcluded: rule.isExcluded,
            isRecurring: true,
            recurringRuleID: rule.id,
            recurrenceOccurrence: occurrenceDate
        ))
        advanceRule()
    }

    private func skipOccurrence() {
        guard rule.isActive else { return }
        isSaving = true
        advanceRule()
    }

    private func advanceRule() {
        if let next = RecurrenceCalendar.nextAllowedDate(for: rule) {
            rule.nextOccurrence = next
        } else {
            rule.isActive = false
        }
        do {
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            isSaving = false
            saveError = error.localizedDescription
        }
    }
}
