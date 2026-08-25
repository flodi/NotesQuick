import Foundation

/// Resolves the security-scoped bookmark for the notes folder and manages
/// sustained access (e.g. while a Quick Look preview is on screen). Security-
/// scoped access is reference-counted, so holding an extra start/stop pair
/// alongside the view model's own access is safe.
enum FolderBookmark {
    static let key = AppGroup.bookmarkKey

    static func resolvedURL() -> URL? {
        guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
        var isStale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        return try? URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    /// Starts scoped access and returns the URL the caller must later release
    /// via `endAccess(_:)`. Returns nil if there is no bookmark (default folder).
    static func beginAccess() -> URL? {
        guard let url = resolvedURL() else { return nil }
        return url.startAccessingSecurityScopedResource() ? url : nil
    }

    static func endAccess(_ url: URL?) {
        url?.stopAccessingSecurityScopedResource()
    }
}
