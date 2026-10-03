import SwiftUI

/// Sheet to set the two per-item dates: "hide until" (snooze) and "remind me on".
struct SchedulePicker: View {
    let note: Note
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var hideOn = false
    @State private var hideDate = SchedulePicker.defaultDate
    @State private var remindOn = false
    @State private var remindDate = SchedulePicker.defaultDate

    static var defaultDate: Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Riga del titolo: i comandi stanno a destra, primaria per prima.
            HStack(spacing: 6) {
                Text(note.title)
                    .font(Q.F.title)
                    .lineLimit(1)
                Spacer(minLength: 8)
                QIconButton(symbol: "checkmark", kind: .primary, help: "Salva") { save() }
                    .keyboardShortcut(.defaultAction)
                QIconButton(symbol: "xmark", kind: .gray, help: "Annulla") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                QIconButton(symbol: "trash", kind: .plain, help: "Cancella pianificazione") {
                    viewModel.setSchedule(ItemSchedule(), for: note)
                    dismiss()
                }
                .disabled(!hideOn && !remindOn)
                .opacity(!hideOn && !remindOn ? 0.4 : 1)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .padding(.vertical, 10)

            Divider()

            Form {
                Section {
                    Toggle("Nascondi fino al", isOn: $hideOn.animation())
                    if hideOn {
                        DatePicker("", selection: $hideDate, in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                } footer: {
                    Text("L'elemento resta nascosto dalla lista fino a questa data.")
                }

                Section {
                    Toggle("Ricordami il", isOn: $remindOn.animation())
                    if remindOn {
                        DatePicker("", selection: $remindDate, in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                    }
                } footer: {
                    Text("Ricevi una notifica a questa data.")
                }
            }
            #if os(macOS)
            .padding(.horizontal, 4)
            #endif
        }
        .frame(minWidth: 340, minHeight: 320)
        .onAppear(perform: load)
    }

    private func load() {
        let s = viewModel.schedule(for: note)
        // Clamp loaded dates to "now or later": a DatePicker with an `in: Date()...`
        // range and a selection in the past can crash on iOS.
        let now = Date()
        if let h = s?.hideUntil { hideOn = true; hideDate = max(h, now) }
        if let r = s?.remindAt { remindOn = true; remindDate = max(r, now) }
    }

    private func save() {
        let schedule = ItemSchedule(
            hideUntil: hideOn ? hideDate : nil,
            remindAt: remindOn ? remindDate : nil
        )
        viewModel.setSchedule(schedule, for: note)
        dismiss()
    }
}

/// A compact badge summarising an item's schedule, for list rows.
struct ScheduleBadge: View {
    let schedule: ItemSchedule

    var body: some View {
        HStack(spacing: 6) {
            if let h = schedule.hideUntil, h > Date() {
                Label(h.quickShort, systemImage: "moon.zzz")
            }
            if let r = schedule.remindAt, r > Date() {
                Label(r.quickShort, systemImage: "bell")
            }
        }
        .font(Q.F.data(ScheduleBadge.size, .regular))
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    #if os(macOS)
    private static let size: CGFloat = 10.5
    #else
    private static let size: CGFloat = 12
    #endif
}
