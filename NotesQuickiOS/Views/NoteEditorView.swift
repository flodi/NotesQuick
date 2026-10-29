import SwiftUI

struct NoteEditorView: View {
    let note: Note
    @EnvironmentObject var viewModel: NotesViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var content: String = ""
    @State private var currentNote: Note?
    @State private var loadedContent: String = ""

    /// Derived from the content loaded from disk, so opening a note (or a SwiftUI
    /// re-render) can never mark it dirty on its own.
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

    var body: some View {
        VStack(spacing: 0) {
            MarkdownTextView(text: $content, hidesTags: viewModel.hideTagsInEditor)
                .frame(maxHeight: .infinity)

            if !tags.isEmpty {
                TagCloudView(tags: tags) { tag in
                    viewModel.searchText = "#\(tag)"
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(Q.C.band)
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem(placement: .primaryAction) {
                    Button("Salva") { save() }
                }
            }
        }
        .onAppear {
            currentNote = note
            content = note.content
            loadedContent = note.content
        }
        .onChange(of: scenePhase) { _, phase in
            // Leaving the app does not close the editor: save now, or the text is lost if
            // iOS later terminates the app in the background.
            if phase != .active, hasUnsavedChanges,
               !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                save()
            }
        }
        .onDisappear {
            guard let note = currentNote else { return }
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                viewModel.deleteNote(note)
            } else if hasUnsavedChanges {
                save()
            }
        }
    }

    private func save() {
        guard let note = currentNote else { return }
        viewModel.saveNote(note, content: content)
        currentNote = viewModel.selectedNote
        loadedContent = content
    }
}
