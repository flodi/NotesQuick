import Foundation

/// Writes shared items into the App Group "Inbox" staging folder. The Share
/// extensions use this: writing to the shared container needs no security-scoped
/// bookmark, so it works on macOS too (where resolving the folder bookmark from
/// an extension is unreliable). The main app drains the Inbox into the notes
/// folder. Standalone (Foundation only) so the extensions can link it directly.
enum NoteFolder {
    static var fileExtension: String {
        AppGroup.defaults.string(forKey: AppGroup.extensionKey) ?? "md"
    }

    static func folderURL() -> URL? { AppGroup.inboxURL() }

    /// Save a URL as a one-line markdown-link note.
    @discardableResult
    static func saveLink(_ url: URL, title: String?) -> URL? {
        let display = clean(title) ?? url.host ?? "Link"
        return writeNote(text: "[\(display)](\(url.absoluteString))", baseName: display)
    }

    /// Save plain text as a note (title derived from the first line).
    @discardableResult
    static func saveText(_ text: String, title: String?) -> URL? {
        let base = clean(title) ?? firstLine(text) ?? "Note"
        return writeNote(text: text, baseName: base)
    }

    /// Copy an external file into the Inbox.
    @discardableResult
    static func copyFile(at source: URL) -> URL? {
        guard let inbox = folderURL() else { return nil }
        let srcAccess = source.startAccessingSecurityScopedResource()
        defer { if srcAccess { source.stopAccessingSecurityScopedResource() } }

        let dest = uniqueURL(in: inbox,
                             base: source.deletingPathExtension().lastPathComponent,
                             ext: source.pathExtension)
        return (try? FileManager.default.copyItem(at: source, to: dest)) != nil ? dest : nil
    }

    // MARK: - Private

    private static func writeNote(text: String, baseName: String) -> URL? {
        guard let inbox = folderURL() else { return nil }
        let dest = uniqueURL(in: inbox, base: sanitize(baseName), ext: fileExtension)
        return (try? text.write(to: dest, atomically: true, encoding: .utf8)) != nil ? dest : nil
    }

    private static func uniqueURL(in folder: URL, base: String, ext: String) -> URL {
        let fm = FileManager.default
        let safeBase = base.isEmpty ? "Untitled" : base
        func make(_ n: Int) -> URL {
            let name = n == 1 ? safeBase : "\(safeBase) \(n)"
            return ext.isEmpty
                ? folder.appendingPathComponent(name)
                : folder.appendingPathComponent("\(name).\(ext)")
        }
        var n = 1
        var url = make(1)
        while fm.fileExists(atPath: url.path) { n += 1; url = make(n) }
        return url
    }

    private static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var result = String(String.UnicodeScalarView(name.unicodeScalars.filter { !invalid.contains($0) }))
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count > 100 { result = String(result.prefix(100)) }
        return result.isEmpty ? "Untitled" : result
    }

    private static func clean(_ s: String?) -> String? {
        guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    private static func firstLine(_ text: String) -> String? {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
    }
}
