import SwiftUI

struct NoteEditorView: View {
    let note: Note
    @EnvironmentObject var viewModel: NotesViewModel
    @State private var content: String = ""
    @State private var currentNote: Note?
    @State private var hasUnsavedChanges = false
    @State private var isLoading = false

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

    var body: some View {
        VStack(spacing: 0) {
            MarkdownTextView(text: $content, hidesTags: viewModel.hideTagsInEditor)
                .frame(maxHeight: .infinity)

            if !tags.isEmpty {
                TagCloudView(tags: tags) { tag in
                    viewModel.searchText = "#\(tag)"
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(Color(uiColor: .secondarySystemBackground))
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if hasUnsavedChanges {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { save() }
                }
            }
        }
        .onChange(of: content) { _, _ in
            if !isLoading { hasUnsavedChanges = true }
        }
        .onAppear {
            isLoading = true
            currentNote = note
            content = note.content
            hasUnsavedChanges = false
            DispatchQueue.main.async { isLoading = false }
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
        hasUnsavedChanges = false
    }
}
