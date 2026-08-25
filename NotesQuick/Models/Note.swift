import Foundation

/// A single item in the notes folder. It can be a text note (.md/.markdown/.txt),
/// a saved link (a one-line text note whose content is a URL / markdown link), or
/// an arbitrary file (PDF, image, Office/iWork document, …) shown with a preview.
struct Note: Identifiable, Hashable {
    var fileURL: URL
    /// Full text for text notes; empty for file items.
    var content: String
    var modifiedDate: Date
    /// True for .md/.markdown/.txt files that the app edits as text.
    var isText: Bool

    /// Extensions treated as editable text notes.
    static let textExtensions: Set<String> = ["txt", "md", "markdown"]

    var id: String { fileURL.path }

    var kind: Kind {
        if !isText { return .file }
        if linkURL != nil { return .link }
        return .text
    }

    enum Kind { case text, link, file }

    /// If this text note is essentially a single link (a shared URL is stored as a
    /// one-line `[title](url)` or a bare URL), returns that URL.
    var linkURL: URL? {
        guard isText else { return nil }
        let lines = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard lines.count == 1 else { return nil }
        return Note.extractURL(from: lines[0])
    }

    private static func extractURL(from line: String) -> URL? {
        // Markdown link: [text](https://…)
        if let r = line.range(of: #"\((https?://[^)\s]+)\)"#, options: .regularExpression) {
            let inside = line[r].dropFirst().dropLast()
            return URL(string: String(inside))
        }
        // Bare URL on its own line.
        if line.range(of: #"^https?://\S+$"#, options: .regularExpression) != nil {
            return URL(string: line)
        }
        return nil
    }

    /// Title derived from the first non-empty line (text notes) or the file name.
    var title: String {
        guard isText else { return fileURL.lastPathComponent }
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
