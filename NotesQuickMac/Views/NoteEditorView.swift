import SwiftUI

struct NoteEditorView: View {
    let noteId: String?
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.openWindow) var openWindow
    @State private var content: String = ""
    @State private var currentNote: Note?
    @State private var loadedContent: String = ""
    @State private var tagQuery: String?

    /// Derived from the content actually loaded from disk, so merely opening a
    /// note (or SwiftUI re-rendering it) can never mark it dirty on its own.
    private var hasUnsavedChanges: Bool { content != loadedContent }

    private var displayTitle: String {
        let firstLine = content
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        let stripped = firstLine.strippingMarkdown()
        return stripped.isEmpty ? L("Nuova nota") : stripped
    }

    private var tags: [String] {
        content.extractTags()
    }

    private var tagResults: [Note] {
        guard let tag = tagQuery else { return [] }
        return viewModel.notes.filter { note in
            note.id != currentNote?.id &&
            note.content.range(of: "(?<!\\w)#\(tag)\\b", options: .regularExpression) != nil
        }
    }

    var body: some View {
        Group {
            if let note = currentNote, !note.isText {
                // File item: native Quick Look preview.
                FilePreviewScreen(url: note.fileURL)
            } else if currentNote != nil {
                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        MarkdownTextView(text: $content, hidesTags: viewModel.hideTagsInEditor)

                        if hasUnsavedChanges {
                            Circle()
                                .fill(Q.C.accent)
                                .frame(width: 8, height: 8)
                                .padding(12)
                                .help("Modifiche non salvate. ⌘S per salvare")
                        }
                    }

                    // Tag search results panel
                    if let tag = tagQuery {
                        VStack(spacing: 0) {
                            Divider()
                            QSectionHeader(title: L("Note con #%@", tag), count: tagResults.count) {
                                QIconButton(symbol: "xmark", kind: .plain, help: L("Chiudi")) { tagQuery = nil }
                            }
                            .padding(.leading, 12)
                            .padding(.trailing, 4)
                            .padding(.vertical, 2)

                            if tagResults.isEmpty {
                                Text("Nessun'altra nota con questo tag")
                                    .font(Q.F.body)
                                    .foregroundStyle(.tertiary)
                                    .padding(.bottom, 10)
                            } else {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(tagResults) { note in
                                            Button {
                                                openNoteInNewWindow(note)
                                            } label: {
                                                HStack {
                                                    Text(note.title)
                                                        .font(Q.F.body)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(note.modifiedDate.quickMeta)
                                                        .font(Q.F.data(10.5, .regular))
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 4)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .frame(maxHeight: 150)
                            }
                        }
                        .background(Q.C.band)
                    }

                    TagCloudView(tags: tags) { tag in
                        tagQuery = tag
                    }
                }
            } else {
                QEmptyState(symbol: "note.text", title: L("Nessuna nota aperta"),
                            message: L("La nota che apri dalla barra dei menu compare qui."))
            }
        }
        .navigationTitle(currentNote.map { $0.isText ? displayTitle : $0.title } ?? displayTitle)
        .onAppear {
            loadNote()
        }
        .onDisappear {
            // Only text notes have the delete-empty / autosave lifecycle; file
            // items must never be deleted just because their text content is empty.
            guard let note = currentNote, note.isText else { return }
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.deleteNote(note)
            } else if hasUnsavedChanges {
                save(note: note)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveCurrentNote)) { _ in
            if let current = currentNote, current.isText {
                save(note: current)
            }
        }
    }

    private func openNoteInNewWindow(_ note: Note) {
        tagQuery = nil
        openWindow(id: "note-editor", value: note.id)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func loadNote() {
        // Find the note by the id passed from the WindowGroup, falling back to
        // selectedNote (for opening from the menu bar).
        let note = noteId.flatMap { id in viewModel.notes.first(where: { $0.id == id }) }
            ?? viewModel.selectedNote
        guard let note else {
            currentNote = nil
            content = ""
            loadedContent = ""
            return
        }
        currentNote = note
        content = note.content
        loadedContent = note.content
    }

    private func save(note: Note) {
        viewModel.saveNote(note, content: content)
        // Update currentNote with potentially renamed note
        if let updated = viewModel.notes.first(where: { $0.content == content }) {
            currentNote = updated
        }
        loadedContent = content
    }
}
