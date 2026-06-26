import Foundation

struct Note: Identifiable, Hashable {
    var fileURL: URL
    var content: String
    var modifiedDate: Date

    var id: String { fileURL.path }

    /// Title derived from the first non-empty line, stripped of markdown tags.
    /// Falls back to the filename if content is empty.
    var title: String {
        let firstLine = content
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        let stripped = firstLine.strippingMarkdown()
        return stripped.isEmpty
            ? fileURL.deletingPathExtension().lastPathComponent
            : stripped
    }

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.fileURL == rhs.fileURL
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(fileURL)
    }
}
