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
        return stripped.isEmpty ? "New Note" : stripped
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
            if currentNote != nil {
                VStack(spacing: 0) {
                    ZStack(alignment: .topTrailing) {
                        MarkdownTextView(text: $content, hidesTags: viewModel.hideTagsInEditor)

                        if hasUnsavedChanges {
                            Circle()
                                .fill(.orange)
                                .frame(width: 8, height: 8)
                                .padding(12)
                                .help("Unsaved changes — Cmd+S to save")
                        }
                    }

                    // Tag search results panel
                    if let tag = tagQuery {
                        VStack(spacing: 0) {
                            Divider()
                            HStack {
                                Text("Notes with #\(tag)")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    tagQuery = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                            if tagResults.isEmpty {
                                Text("No other notes found")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(8)
                            } else {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(tagResults) { note in
                                            Button {
                                                openNoteInNewWindow(note)
                                            } label: {
                                                HStack {
                                                    Text(note.title)
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text(note.modifiedDate, style: .relative)
                                                        .font(.caption2)
                                                        .foregroundStyle(.secondary)
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 4)
                                                .contentShape(Rectangle())
                                            }
                                            .buttonStyle(.plain)
                                            Divider().padding(.leading, 12)
                                        }
                                    }
                                }
                                .frame(maxHeight: 150)
                            }
                        }
                        .background(Color(nsColor: .controlBackgroundColor))
                    }

                    TagCloudView(tags: tags) { tag in
                        tagQuery = tag
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a note to edit")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(displayTitle)
        .onAppear {
            loadNote()
        }
        .onDisappear {
            guard let note = currentNote else { return }
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.deleteNote(note)
            } else if hasUnsavedChanges {
                save(note: note)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveCurrentNote)) { _ in
            if let current = currentNote {
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
