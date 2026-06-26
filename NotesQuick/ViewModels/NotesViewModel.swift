import Foundation
import SwiftUI

class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNote: Note?
    @Published var searchText: String = ""

    @Published var notesFolderPath: String {
        didSet {
            UserDefaults.standard.set(notesFolderPath, forKey: "notesFolderPath")
            ensureFolderExists()
            loadNotes()
        }
    }

    @Published var fileExtension: String {
        didSet {
            UserDefaults.standard.set(fileExtension, forKey: "fileExtension")
            loadNotes()
        }
    }

    @Published var hideTagsInEditor: Bool {
        didSet {
            UserDefaults.standard.set(hideTagsInEditor, forKey: "hideTagsInEditor")
        }
    }

    var notesFolder: URL {
        URL(fileURLWithPath: notesFolderPath)
    }

    var filteredNotes: [Note] {
        let sorted = notes.sorted { $0.modifiedDate > $1.modifiedDate }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    init() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultPath = docsDir.appendingPathComponent("NotesQuick").path
        self.notesFolderPath = UserDefaults.standard.string(forKey: "notesFolderPath") ?? defaultPath
        self.fileExtension = UserDefaults.standard.string(forKey: "fileExtension") ?? "md"
        self.hideTagsInEditor = UserDefaults.standard.bool(forKey: "hideTagsInEditor")
        ensureFolderExists()
        loadNotes()
    }

    func ensureFolderExists() {
        startFolderAccess()
        defer { stopFolderAccess() }
        let fm = FileManager.default
        if !fm.fileExists(atPath: notesFolderPath) {
            try? fm.createDirectory(at: notesFolder, withIntermediateDirectories: true)
        }
    }

    func loadNotes() {
        startFolderAccess()
        defer { stopFolderAccess() }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: notesFolder,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            notes = []
            return
        }

        notes = files.compactMap { url -> Note? in
            guard url.pathExtension == fileExtension else { return nil }
            guard let content = try? String(contentsOf: url, encoding: .utf8),
                  let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let modDate = attrs[.modificationDate] as? Date
            else { return nil }
            return Note(fileURL: url, content: content, modifiedDate: modDate)
        }
    }

    @discardableResult
    func createNote() -> Note {
        startFolderAccess()
        defer { stopFolderAccess() }
        ensureFolderExists()

        var name = "Untitled"
        var counter = 1
        let fm = FileManager.default

        func isTaken(_ candidate: String) -> Bool {
            let url = notesFolder.appendingPathComponent("\(candidate).\(fileExtension)")
            return fm.fileExists(atPath: url.path) || notes.contains { $0.fileURL == url }
        }

        while isTaken(name) {
            counter += 1
            name = "Untitled \(counter)"
        }

        let url = notesFolder.appendingPathComponent("\(name).\(fileExtension)")
        // Don't create the file on disk yet — a brand-new note lives only in memory
        // until it actually has content. Writing an empty "Untitled" file here would
        // sync it (e.g. to Dropbox) the moment the editor is opened and closed without
        // typing, leaving phantom empty notes that then delete themselves on reopen.
        let note = Note(fileURL: url, content: "", modifiedDate: Date())
        notes.insert(note, at: 0)
        return note
    }

    func saveNote(_ note: Note, content: String) {
        startFolderAccess()
        defer { stopFolderAccess() }
        let firstLine = content
            .components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        let title = firstLine.strippingMarkdown()
        let safeName = sanitizeFilename(title.isEmpty ? "Untitled" : title)

        let newURL = notesFolder.appendingPathComponent("\(safeName).\(fileExtension)")
        let fm = FileManager.default
        var targetURL = note.fileURL

        if newURL.lastPathComponent != note.fileURL.lastPathComponent,
           !fm.fileExists(atPath: newURL.path) {
            // Rename the file to match the title. A brand-new note has no file on
            // disk yet, so there's nothing to move — we just write straight to the
            // title-based name instead of leaving an "Untitled" file behind.
            if fm.fileExists(atPath: note.fileURL.path) {
                try? fm.moveItem(at: note.fileURL, to: newURL)
            }
            targetURL = newURL
        }

        // Skip the write when the file on disk already holds this exact content.
        // Every save uses an atomic write, which replaces the file (new inode +
        // modification date); sync engines like Dropbox treat that as a brand-new
        // version and re-upload it. Since the editor re-saves on every close —
        // even when the note was only opened and viewed — two devices touching the
        // same file end up creating "conflicted copies" for no real reason.
        let unchanged = (try? String(contentsOf: targetURL, encoding: .utf8)) == content

        if !unchanged {
            try? content.write(to: targetURL, atomically: true, encoding: .utf8)
        }

        // Keep the in-memory model in sync (the file may have been renamed above,
        // or its content updated). When nothing was written, preserve the existing
        // modification date so the list ordering doesn't jump around spuriously.
        let modifiedDate = unchanged ? note.modifiedDate : Date()
        let updatedNote = Note(fileURL: targetURL, content: content, modifiedDate: modifiedDate)

        if let index = notes.firstIndex(where: { $0.fileURL == note.fileURL }) {
            notes[index] = updatedNote
        }

        if selectedNote?.fileURL == note.fileURL {
            selectedNote = updatedNote
        }
    }

    func deleteNote(_ note: Note) {
        startFolderAccess()
        defer { stopFolderAccess() }
        try? FileManager.default.removeItem(at: note.fileURL)
        notes.removeAll { $0.fileURL == note.fileURL }
        if selectedNote?.fileURL == note.fileURL {
            selectedNote = nil
        }
    }

    // MARK: - Security-Scoped Bookmark

    private var currentAccessedURL: URL?

    func setNotesFolderFromPicker(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = [.minimalBookmark]
        #endif

        if let bookmark = try? url.bookmarkData(
            options: options,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(bookmark, forKey: "notesFolderBookmark")
        }

        notesFolderPath = url.path
    }

    func startFolderAccess() {
        guard let data = UserDefaults.standard.data(forKey: "notesFolderBookmark") else { return }
        var isStale = false

        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif

        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return }

        if url.startAccessingSecurityScopedResource() {
            currentAccessedURL = url
        }

        if isStale {
            #if os(macOS)
            let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
            #else
            let bookmarkOptions: URL.BookmarkCreationOptions = [.minimalBookmark]
            #endif
            if let newData = try? url.bookmarkData(
                options: bookmarkOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                UserDefaults.standard.set(newData, forKey: "notesFolderBookmark")
            }
        }
    }

    func stopFolderAccess() {
        currentAccessedURL?.stopAccessingSecurityScopedResource()
        currentAccessedURL = nil
    }

    // MARK: - Private

    private func sanitizeFilename(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:*?\"<>|")
        let sanitized = name.unicodeScalars.filter { !invalid.contains($0) }
        var result = String(String.UnicodeScalarView(sanitized))
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.count > 100 {
            result = String(result.prefix(100))
        }
        return result.isEmpty ? "Untitled" : result
    }
}
