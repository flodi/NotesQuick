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
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
                .padding()

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

            Divider()

            HStack {
                Button("Cancella pianificazione", role: .destructive) {
                    viewModel.setSchedule(ItemSchedule(), for: note)
                    dismiss()
                }
                .disabled(!hideOn && !remindOn)

                Spacer()

                Button("Annulla") { dismiss() }
                Button("Salva") { save() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 340, minHeight: 320)
        .onAppear(perform: load)
    }

    private func load() {
        let s = viewModel.schedule(for: note)
        if let h = s?.hideUntil { hideOn = true; hideDate = h }
        if let r = s?.remindAt { remindOn = true; remindDate = r }
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
                Label(h.formatted(.dateTime.day().month(.abbreviated)), systemImage: "moon.zzz")
                    .foregroundStyle(.orange)
            }
            if let r = schedule.remindAt, r > Date() {
                Label(r.formatted(.dateTime.day().month(.abbreviated)), systemImage: "bell")
                    .foregroundStyle(.blue)
            }
        }
        .font(.caption2)
        .labelStyle(.titleAndIcon)
    }
}
