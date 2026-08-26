import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedNoteID: String?
    @State private var showSettings = false
    @State private var showFileImporter = false
    @State private var showLinkPrompt = false
    @State private var linkText = ""
    @State private var scheduleTarget: Note?

    private var selectedNote: Note? {
        guard let id = selectedNoteID else { return nil }
        return viewModel.notes.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationSplitView {
            List(viewModel.filteredNotes, selection: $selectedNoteID) { note in
                NoteRow(note: note, schedule: viewModel.schedule(for: note))
                    .tag(note.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if selectedNoteID == note.id { selectedNoteID = nil }
                            viewModel.deleteNote(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            scheduleTarget = note
                        } label: {
                            Label("Pianifica", systemImage: "clock")
                        }
                        .tint(.orange)
                    }
                    .contextMenu {
                        Button { scheduleTarget = note } label: { Label("Pianifica…", systemImage: "clock") }
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
                if viewModel.snoozedCount > 0 || viewModel.showSnoozed {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { viewModel.showSnoozed.toggle() } label: {
                            Image(systemName: viewModel.showSnoozed ? "moon.zzz.fill" : "moon.zzz")
                        }
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
        .sheet(item: $scheduleTarget) { note in
            NavigationStack {
                SchedulePicker(note: note)
                    .environmentObject(viewModel)
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            viewModel.loadNotes()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.loadNotes() }
        }
    }
}

// MARK: - Note Row

struct NoteRow: View {
    let note: Note
    var schedule: ItemSchedule?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: NoteIcon.symbol(for: note))
                .foregroundStyle(NoteIcon.color(for: note))
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(note.modifiedDate, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let schedule, !schedule.isEmpty {
                        ScheduleBadge(schedule: schedule)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
