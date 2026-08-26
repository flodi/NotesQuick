import Foundation
import SwiftUI

class NotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedNote: Note?
    @Published var searchText: String = ""

    /// Per-item schedules (hide-until / remind-at), keyed by file name.
    @Published var schedules: [String: ItemSchedule] = [:]
    /// When true, snoozed ("hide until") items are shown too.
    @Published var showSnoozed: Bool = false

    @Published var notesFolderPath: String {
        didSet {
            AppGroup.defaults.set(notesFolderPath, forKey: AppGroup.pathKey)
            ensureFolderExists()
            loadNotes()
            startWatching()
        }
    }

    @Published var fileExtension: String {
        didSet {
            AppGroup.defaults.set(fileExtension, forKey: AppGroup.extensionKey)
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

    private let folderWatcher = FolderWatcher()

    private func startWatching() {
        folderWatcher.onChange = { [weak self] in self?.loadNotes() }
        folderWatcher.start(path: notesFolderPath)
    }

    var filteredNotes: [Note] {
        let now = Date()
        var items = notes
        // Hide snoozed items whose "hide until" is still in the future.
        if !showSnoozed {
            items = items.filter { !(schedule(for: $0)?.isHidden(now: now) ?? false) }
        }
        let sorted = items.sorted { $0.modifiedDate > $1.modifiedDate }
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText) ||
            $0.fileURL.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Number of items currently hidden by a "hide until" in the future.
    var snoozedCount: Int {
        let now = Date()
        return notes.filter { schedule(for: $0)?.isHidden(now: now) ?? false }.count
    }

    func schedule(for note: Note) -> ItemSchedule? {
        schedules[note.fileURL.lastPathComponent]
    }

    init() {
        AppGroup.migrateFromStandardIfNeeded()
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let defaultPath = docsDir.appendingPathComponent("NotesQuick").path
        self.notesFolderPath = AppGroup.defaults.string(forKey: AppGroup.pathKey) ?? defaultPath
        self.fileExtension = AppGroup.defaults.string(forKey: AppGroup.extensionKey) ?? "md"
        self.hideTagsInEditor = UserDefaults.standard.bool(forKey: "hideTagsInEditor")
        ensureFolderExists()
        loadNotes()
        startWatching()
        Reminders.requestAuthorization()
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

        let loaded = files.compactMap { url -> Note? in
            // Skip subdirectories (e.g. a Trash folder).
            var isDir: ObjCBool = false
            fm.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue { return nil }

            guard let attrs = try? fm.attributesOfItem(atPath: url.path),
                  let modDate = attrs[.modificationDate] as? Date
            else { return nil }

            if Note.textExtensions.contains(url.pathExtension.lowercased()) {
                let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
                return Note(fileURL: url, content: content, modifiedDate: modDate, isText: true)
            } else {
                // Any other file (PDF, image, Office/iWork, …) is a file item.
                return Note(fileURL: url, content: "", modifiedDate: modDate, isText: false)
            }
        }
        // Preserve brand-new notes that live only in memory (no file on disk yet),
        // so a folder-watch reload doesn't wipe an unsaved new note.
        let pending = notes.filter { !FileManager.default.fileExists(atPath: $0.fileURL.path) }
        notes = pending + loaded.filter { l in !pending.contains(where: { $0.fileURL == l.fileURL }) }
        loadSchedules()
    }

    // MARK: - Schedules (hide-until / remind-at)

    private var scheduleIndexURL: URL {
        notesFolder.appendingPathComponent(ScheduleIndex.fileName)
    }

    private func loadSchedules() {
        startFolderAccess()
        defer { stopFolderAccess() }
        if let data = try? Data(contentsOf: scheduleIndexURL) {
            schedules = ScheduleIndex.decode(data)
        } else {
            schedules = [:]
        }
        // Drop entries for items that no longer exist, then reconcile reminders.
        let names = Set(notes.map { $0.fileURL.lastPathComponent })
        schedules = schedules.filter { names.contains($0.key) }
        reconcileReminders()
    }

    private func saveSchedules() {
        startFolderAccess()
        defer { stopFolderAccess() }
        let pruned = schedules.filter { !$0.value.isEmpty }
        schedules = pruned
        if pruned.isEmpty {
            try? FileManager.default.removeItem(at: scheduleIndexURL)
        } else if let data = ScheduleIndex.encode(pruned) {
            try? data.write(to: scheduleIndexURL, options: .atomic)
        }
        reconcileReminders()
    }

    private func reconcileReminders() {
        let titles = Dictionary(uniqueKeysWithValues: notes.map { ($0.fileURL.lastPathComponent, $0.title) })
        Reminders.sync(schedules) { name in titles[name] ?? name }
    }

    /// Set (or clear) the schedule for an item and persist it.
    func setSchedule(_ schedule: ItemSchedule, for note: Note) {
        let name = note.fileURL.lastPathComponent
        if schedule.isEmpty {
            schedules.removeValue(forKey: name)
        } else {
            schedules[name] = schedule
        }
        saveSchedules()
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
        let note = Note(fileURL: url, content: "", modifiedDate: Date(), isText: true)
        notes.insert(note, at: 0)
        return note
    }

    /// Save a shared/added URL as a one-line markdown-link text note.
    @discardableResult
    func addLink(_ url: URL, title: String?) -> Note {
        startFolderAccess()
        defer { stopFolderAccess() }
        ensureFolderExists()

        let display = (title?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? url.host
            ?? "Link"
        let content = "[\(display)](\(url.absoluteString))"
        let safe = sanitizeFilename(display)
        let fm = FileManager.default

        var fileURL = notesFolder.appendingPathComponent("\(safe).\(fileExtension)")
        var counter = 2
        while fm.fileExists(atPath: fileURL.path) {
            fileURL = notesFolder.appendingPathComponent("\(safe) \(counter).\(fileExtension)")
            counter += 1
        }

        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        let note = Note(fileURL: fileURL, content: content, modifiedDate: Date(), isText: true)
        notes.insert(note, at: 0)
        return note
    }

    /// Copy an external file into the notes folder as a file item.
    @discardableResult
    func importFile(at sourceURL: URL) -> Note? {
        startFolderAccess()
        defer { stopFolderAccess() }
        ensureFolderExists()

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let fm = FileManager.default
        let base = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension

        var dest = notesFolder.appendingPathComponent(sourceURL.lastPathComponent)
        var counter = 2
        while fm.fileExists(atPath: dest.path) {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            dest = notesFolder.appendingPathComponent(name)
            counter += 1
        }

        guard (try? fm.copyItem(at: sourceURL, to: dest)) != nil else { return nil }
        let note = Note(fileURL: dest, content: "", modifiedDate: Date(), isText: false)
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
        let updatedNote = Note(fileURL: targetURL, content: content, modifiedDate: modifiedDate, isText: true)

        if let index = notes.firstIndex(where: { $0.fileURL == note.fileURL }) {
            notes[index] = updatedNote
        }

        // Follow the schedule to the renamed file.
        let oldName = note.fileURL.lastPathComponent
        let newName = targetURL.lastPathComponent
        if oldName != newName, let sched = schedules[oldName] {
            schedules.removeValue(forKey: oldName)
            schedules[newName] = sched
            saveSchedules()
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
        let name = note.fileURL.lastPathComponent
        if schedules[name] != nil {
            schedules.removeValue(forKey: name)
            saveSchedules()
        }
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
            AppGroup.defaults.set(bookmark, forKey: AppGroup.bookmarkKey)
        }

        notesFolderPath = url.path
    }

    func startFolderAccess() {
        guard let data = AppGroup.defaults.data(forKey: AppGroup.bookmarkKey) else { return }
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
                AppGroup.defaults.set(newData, forKey: AppGroup.bookmarkKey)
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
