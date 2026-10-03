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
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    private var selectedNote: Note? {
        guard let id = selectedNoteID else { return nil }
        return viewModel.notes.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(viewModel.filteredNotes, selection: $selectedNoteID) { note in
                NoteRow(note: note, schedule: viewModel.schedule(for: note))
                    .tag(note.id)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if selectedNoteID == note.id { selectedNoteID = nil }
                            viewModel.deleteNote(note)
                        } label: {
                            Label("Elimina", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            scheduleTarget = note
                        } label: {
                            Label("Pianifica", systemImage: "clock")
                        }
                        .tint(Q.C.accent)
                    }
                    .contextMenu {
                        Button { scheduleTarget = note } label: { Label("Pianifica…", systemImage: "clock") }
                    }
            }
            .searchable(text: $viewModel.searchText, prompt: "Cerca")
            .navigationTitle("NotesQuick")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            let note = viewModel.createNote()
                            selectedNoteID = note.id
                        } label: { Label("Nuova nota", systemImage: "note.text") }
                        Button { showLinkPrompt = true } label: { Label("Aggiungi link", systemImage: "link") }
                        Button { showFileImporter = true } label: { Label("Aggiungi file", systemImage: "doc") }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nuovo elemento")
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Impostazioni")
                }
                if viewModel.snoozedCount > 0 || viewModel.showSnoozed {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { viewModel.showSnoozed.toggle() } label: {
                            Image(systemName: viewModel.showSnoozed ? "moon.zzz.fill" : "moon.zzz")
                        }
                        .accessibilityLabel(viewModel.showSnoozed ? L("Nascondi sospesi") : L("Mostra sospesi"))
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
                QEmptyState(title: L("Nessun elemento aperto"),
                            message: L("La nota o il file che scegli dall'elenco compare qui."))
            }
        }
        #if DEBUG
        .modifier(ScreenshotSplitStyle())
        #endif
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
                    .navigationTitle("Impostazioni")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fine") { showSettings = false }
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
        .alert("Aggiungi link", isPresented: $showLinkPrompt) {
            TextField("https://example.com", text: $linkText)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
            Button("Aggiungi") {
                let text = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = text.contains("://") ? text : "https://\(text)"
                if !text.isEmpty, let url = URL(string: normalized) {
                    viewModel.addLink(url, title: nil)
                }
                linkText = ""
            }
            Button("Annulla", role: .cancel) { linkText = "" }
        } message: {
            Text("Incolla un URL per salvarlo tra gli elementi.")
        }
        .sheet(item: $scheduleTarget) { note in
            SchedulePicker(note: note)
                .environmentObject(viewModel)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            viewModel.loadNotes()
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "screenshotMode") { columnVisibility = .all }
            // Store screenshots: `-screenshotNote <title>` opens that item, `-screenshotSchedule YES` its schedule sheet.
            if let wanted = UserDefaults.standard.string(forKey: "screenshotNote"),
               let note = viewModel.notes.first(where: { $0.title.localizedCaseInsensitiveContains(wanted) }) {
                if UserDefaults.standard.bool(forKey: "screenshotSchedule") {
                    scheduleTarget = note
                } else {
                    selectedNoteID = note.id
                }
            }
            #endif
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
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(note.title)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(note.modifiedDate.quickMeta)
                        .font(Q.F.data(12, .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(1)
                    if let schedule, !schedule.isEmpty {
                        ScheduleBadge(schedule: schedule)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#if DEBUG
/// Store screenshots on iPad in portrait: list and editor side by side.
private struct ScreenshotSplitStyle: ViewModifier {
    func body(content: Content) -> some View {
        if UserDefaults.standard.bool(forKey: "screenshotMode") {
            content.navigationSplitViewStyle(.balanced)
        } else {
            content
        }
    }
}
#endif
