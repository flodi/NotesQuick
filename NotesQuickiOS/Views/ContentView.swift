import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @State private var selectedNoteID: String?
    @State private var showSettings = false

    private var selectedNote: Note? {
        guard let id = selectedNoteID else { return nil }
        return viewModel.notes.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationSplitView {
            List(viewModel.filteredNotes, selection: $selectedNoteID) { note in
                NoteRow(note: note)
                    .tag(note.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if selectedNoteID == note.id {
                                selectedNoteID = nil
                            }
                            viewModel.deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search notes")
            .navigationTitle("NotesQuick")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        let note = viewModel.createNote()
                        selectedNoteID = note.id
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        } detail: {
            if let note = selectedNote {
                NoteEditorView(note: note)
                    .id(note.id)
            } else {
                ContentUnavailableView(
                    "Select a Note",
                    systemImage: "note.text",
                    description: Text("Choose a note from the list or create a new one")
                )
            }
        }
        .onChange(of: selectedNoteID) { _, newID in
            viewModel.selectedNote = newID.flatMap { id in
                viewModel.notes.first(where: { $0.id == id })
            }
        }
        .onChange(of: viewModel.selectedNote) { _, newNote in
            if selectedNoteID != newNote?.id {
                selectedNoteID = newNote?.id
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .environmentObject(viewModel)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
        }
        .onAppear {
            viewModel.loadNotes()
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            Text(note.modifiedDate, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
