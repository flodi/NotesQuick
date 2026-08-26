import Foundation

/// Watches the notes folder for changes (files added/removed by the Share
/// extension, or synced in by Dropbox) and fires `onChange` — debounced — so the
/// list can reload without the user having to reopen the app.
final class FolderWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var scopedURL: URL?
    private var pending: DispatchWorkItem?

    var onChange: (() -> Void)?

    func start(path: String) {
        stop()
        // Hold security-scoped access to the folder for the watcher's lifetime.
        scopedURL = FolderBookmark.beginAccess()
        let watchPath = scopedURL?.path ?? path
        fd = open(watchPath, O_EVTONLY)
        guard fd >= 0 else {
            FolderBookmark.endAccess(scopedURL); scopedURL = nil
            return
        }
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: .main
        )
        src.setEventHandler { [weak self] in self?.debounced() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
            self?.fd = -1
        }
        source = src
        src.resume()
    }

    func stop() {
        pending?.cancel(); pending = nil
        source?.cancel(); source = nil
        FolderBookmark.endAccess(scopedURL); scopedURL = nil
    }

    private func debounced() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    deinit { stop() }
}
