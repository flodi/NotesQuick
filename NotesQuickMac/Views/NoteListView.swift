import SwiftUI
import UniformTypeIdentifiers

struct NoteListView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.openWindow) var openWindow
    @State private var scheduleTarget: Note?

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar: view on the left, content commands on the right.
            HStack(spacing: 6) {
                QWordmark()

                if viewModel.snoozedCount > 0 || viewModel.showSnoozed {
                    QIconButton(
                        symbol: viewModel.showSnoozed ? "moon.zzz.fill" : "moon.zzz",
                        kind: viewModel.showSnoozed ? .tinted : .plain,
                        help: viewModel.showSnoozed ? "Nascondi sospesi" : "Mostra sospesi (\(viewModel.snoozedCount))"
                    ) { viewModel.showSnoozed.toggle() }
                    .padding(.leading, 4)
                }

                Spacer(minLength: 0)

                Menu {
                    Button {
                        let note = viewModel.createNote()
                        openWindow(id: "note-editor", value: note.id)
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } label: { Label("Nuova nota", systemImage: "note.text") }
                    Button { addLink() } label: { Label("Aggiungi link…", systemImage: "link") }
                    Button { addFile() } label: { Label("Aggiungi file…", systemImage: "doc") }
                } label: {
                    menuLabel("plus", primary: true)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Nuovo elemento")
                .accessibilityLabel("Nuovo elemento")

                Menu {
                    Button {
                        openWindow(id: "settings")
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } label: { Label("Preferenze…", systemImage: "gear") }
                    Button { showAbout() } label: { Label("Informazioni su NotesQuick", systemImage: "info.circle") }
                    Divider()
                    Button { NSApplication.shared.terminate(nil) } label: { Label("Esci", systemImage: "power") }
                } label: {
                    menuLabel("ellipsis", primary: false)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Altro")
                .accessibilityLabel("Altro")
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                TextField("Cerca", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(Q.F.body)
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Cancella ricerca")
                    .accessibilityLabel("Cancella ricerca")
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: Q.R.control).fill(Q.C.fill1))
            .padding(.horizontal, 10)

            QSectionHeader(title: "Elementi", count: viewModel.filteredNotes.count) { EmptyView() }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 4)

            // Items list
            if viewModel.filteredNotes.isEmpty {
                if viewModel.searchText.isEmpty {
                    QEmptyState(title: "Nessun elemento",
                                message: "Le note, i link e i file che aggiungi compaiono qui.")
                } else {
                    QEmptyState(symbol: "magnifyingglass", title: "Nessun risultato")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(viewModel.filteredNotes) { note in
                            NoteRow(note: note, schedule: viewModel.schedule(for: note)) {
                                open(note)
                            } onDelete: {
                                confirmDelete(note: note)
                            } onSchedule: {
                                scheduleTarget = note
                            }
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }
            }
        }
        .frame(width: 300, height: 400)
        .onAppear {
            viewModel.loadNotes()
        }
        .sheet(item: $scheduleTarget) { note in
            SchedulePicker(note: note)
                .environmentObject(viewModel)
        }
    }

    /// Same look as `QIconButton`, for the label of a `Menu`.
    private func menuLabel(_ symbol: String, primary: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(primary ? Color.white : Color.secondary)
            .frame(width: Q.Size.action.width, height: Q.Size.action.height)
            .background(RoundedRectangle(cornerRadius: Q.R.control).fill(primary ? Q.C.accent : Color.clear))
            .contentShape(Rectangle())
    }

    private func open(_ note: Note) {
        if note.kind == .link, let url = note.linkURL {
            NSWorkspace.shared.open(url)
        } else {
            openWindow(id: "note-editor", value: note.id)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    private func addLink() {
        let alert = NSAlert()
        alert.messageText = "Aggiungi link"
        alert.informativeText = "Incolla un URL per salvarlo tra gli elementi."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://example.com"
        alert.accessoryView = field
        alert.addButton(withTitle: "Aggiungi")
        alert.addButton(withTitle: "Annulla")
        if alert.runModal() == .alertFirstButtonReturn {
            let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = text.contains("://") ? text : "https://\(text)"
            if !text.isEmpty, let url = URL(string: normalized) {
                let note = viewModel.addLink(url, title: nil)
                _ = note
            }
        }
    }

    private func addFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.message = "Scegli i file da aggiungere"
        if panel.runModal() == .OK {
            for url in panel.urls {
                viewModel.importFile(at: url)
            }
        }
    }

    private func showAbout() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let build = info?["CFBundleVersion"] as? String ?? ""
        let alert = NSAlert()
        alert.messageText = "NotesQuick"
        alert.informativeText = """
        Versione \(version) (\(build))

        Note, link e file a portata di barra dei menu, con Markdown in tempo reale.
        """
        alert.icon = NSImage(named: "AppIcon")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func confirmDelete(note: Note) {
        let alert = NSAlert()
        alert.messageText = "Elimina"
        alert.informativeText = "Vuoi eliminare «\(note.title)»?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Elimina")
        alert.addButton(withTitle: "Annulla")

        if alert.runModal() == .alertFirstButtonReturn {
            viewModel.deleteNote(note)
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let note: Note
    let schedule: ItemSchedule?
    let onTap: () -> Void
    let onDelete: () -> Void
    let onSchedule: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: NoteIcon.symbol(for: note))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title)
                            .font(Q.F.body)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(note.modifiedDate.quickMeta)
                                .font(Q.F.data(10.5, .regular))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let schedule, !schedule.isEmpty {
                                ScheduleBadge(schedule: schedule)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: Q.Size.action.height, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Desktop: row actions appear on hover only.
            if isHovering {
                QIconButton(symbol: "clock", kind: .plain, help: "Pianifica", action: onSchedule)
                QIconButton(symbol: "trash", kind: .plain, help: "Elimina", action: onDelete)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, isHovering ? 2 : 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: Q.R.row).fill(isHovering ? Color(hex: 0x787880, alpha: 0.10) : Color.clear))
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button { onSchedule() } label: { Label("Pianifica…", systemImage: "clock") }
            Button(role: .destructive) { onDelete() } label: { Label("Elimina", systemImage: "trash") }
        }
    }
}
