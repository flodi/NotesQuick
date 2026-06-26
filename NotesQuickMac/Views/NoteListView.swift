import SwiftUI

struct NoteListView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.openWindow) var openWindow

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

            // Notes list
            if viewModel.filteredNotes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(viewModel.searchText.isEmpty ? "No notes yet" : "No results")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredNotes) { note in
                            NoteRow(note: note) {
                                openWindow(id: "note-editor", value: note.id)
                                NSApplication.shared.activate(ignoringOtherApps: true)
                            } onDelete: {
                                confirmDelete(note: note)
                            }
                            Divider()
                        }
                    }
                }
            }

            Divider()

            // Bottom bar
            HStack {
                Button {
                    let note = viewModel.createNote()
                    openWindow(id: "note-editor", value: note.id)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                } label: {
                    Label("New Note", systemImage: "plus")
                }
                .buttonStyle(.plain)

                Spacer()

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
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "NotesQuick"
        alert.informativeText = """
        Version 1.0.0

        A simple menu bar notes app with live Markdown editing.

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
        alert.messageText = "Delete Note"
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
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(note.modifiedDate, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHovering {
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
    }
}
