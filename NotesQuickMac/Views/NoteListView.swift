import SwiftUI
import UniformTypeIdentifiers

struct NoteListView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.openWindow) var openWindow
    @State private var scheduleTarget: Note?

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)

            Divider()

            // Items list
            if viewModel.filteredNotes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(viewModel.searchText.isEmpty ? "Nothing here yet" : "No results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredNotes) { note in
                            NoteRow(note: note, schedule: viewModel.schedule(for: note)) {
                                open(note)
                            } onDelete: {
                                confirmDelete(note: note)
                            } onSchedule: {
                                scheduleTarget = note
                            }
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Bottom bar
            HStack {
                Menu {
                    Button {
                        let note = viewModel.createNote()
                        openWindow(id: "note-editor", value: note.id)
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } label: { Label("New Note", systemImage: "note.text") }
                    Button { addLink() } label: { Label("Add Link…", systemImage: "link") }
                    Button { addFile() } label: { Label("Add File…", systemImage: "doc") }
                } label: {
                    Label("New", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()

                if viewModel.snoozedCount > 0 || viewModel.showSnoozed {
                    Button { viewModel.showSnoozed.toggle() } label: {
                        Image(systemName: viewModel.showSnoozed ? "moon.zzz.fill" : "moon.zzz")
                    }
                    .buttonStyle(.plain)
                    .help(viewModel.showSnoozed ? "Nascondi sospesi" : "Mostra sospesi (\(viewModel.snoozedCount))")
                }

                Button { showAbout() } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)

                Button {
                    openWindow(id: "settings")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
            .padding(10)
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
        alert.messageText = "Add Link"
        alert.informativeText = "Paste a URL to save it as a note."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.placeholderString = "https://example.com"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
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
        panel.message = "Choose file(s) to add"
        if panel.runModal() == .OK {
            for url in panel.urls {
                viewModel.importFile(at: url)
            }
        }
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "NotesQuick"
        alert.informativeText = """
        Version 1.0.0

        A menu bar app for quick notes, links and files with live Markdown editing.

        App Icon: "Bloc Notes SZ" by Fmaunier
        Licensed under Creative Commons Attribution-ShareAlike 3.0 (CC BY-SA 3.0)
        https://creativecommons.org/licenses/by-sa/3.0/
        Source: Wikimedia Commons
        """
        alert.icon = NSImage(named: "AppIcon")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func confirmDelete(note: Note) {
        let alert = NSAlert()
        alert.messageText = "Delete"
        alert.informativeText = "Are you sure you want to delete '\(note.title)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

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
        HStack(spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Image(systemName: NoteIcon.symbol(for: note))
                        .font(.body)
                        .foregroundColor(NoteIcon.color(for: note))
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 8) {
                            Text(note.modifiedDate, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let schedule, !schedule.isEmpty {
                                ScheduleBadge(schedule: schedule)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHovering {
                Button(action: onSchedule) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Pianifica (nascondi / ricorda)")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button { onSchedule() } label: { Label("Pianifica…", systemImage: "clock") }
            Button(role: .destructive) { onDelete() } label: { Label("Elimina", systemImage: "trash") }
        }
    }
}
