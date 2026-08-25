import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.openURL) private var openURL
    @State private var selectedNoteID: String?
    @State private var showSettings = false
    @State private var showFileImporter = false
    @State private var showLinkPrompt = false
    @State private var linkText = ""

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
                            if selectedNoteID == note.id { selectedNoteID = nil }
                            viewModel.deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search")
            .navigationTitle("NotesQuick")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            let note = viewModel.createNote()
                            selectedNoteID = note.id
                        } label: { Label("New Note", systemImage: "note.text") }
                        Button { showLinkPrompt = true } label: { Label("Add Link", systemImage: "link") }
                        Button { showFileImporter = true } label: { Label("Add File", systemImage: "doc") }
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
                if note.isText {
                    NoteEditorView(note: note).id(note.id)
                } else {
                    FilePreviewScreen(url: note.fileURL)
                        .id(note.id)
                        .navigationTitle(note.title)
                        .navigationBarTitleDisplayMode(.inline)
                        .ignoresSafeArea(edges: .bottom)
                }
            } else {
                ContentUnavailableView(
                    "Select an Item",
                    systemImage: "tray",
                    description: Text("Choose a note, link or file — or add a new one")
                )
            }
        }
        .onChange(of: selectedNoteID) { _, newID in
            let note = newID.flatMap { id in viewModel.notes.first(where: { $0.id == id }) }
            // Tapping a saved link opens it instead of showing a detail view.
            if let note, note.kind == .link, let url = note.linkURL {
                openURL(url)
                selectedNoteID = nil
                viewModel.selectedNote = nil
                return
            }
            viewModel.selectedNote = note
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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                for url in urls { viewModel.importFile(at: url) }
            }
        }
        .alert("Add Link", isPresented: $showLinkPrompt) {
            TextField("https://example.com", text: $linkText)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Button("Add") {
                let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = text.contains("://") ? text : "https://\(text)"
                if !text.isEmpty, let url = URL(string: normalized) {
                    viewModel.addLink(url, title: nil)
                }
                linkText = ""
            }
            Button("Cancel", role: .cancel) { linkText = "" }
        } message: {
            Text("Paste a URL to save it as a note.")
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
        HStack(spacing: 10) {
            Image(systemName: NoteIcon.symbol(for: note))
                .foregroundStyle(NoteIcon.color(for: note))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(note.modifiedDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
