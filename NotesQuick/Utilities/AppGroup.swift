import Foundation

/// Shared storage between the app and its Share extensions. The notes-folder
/// bookmark, path and file extension live here so an extension can resolve the
/// user-chosen folder and write into it.
enum AppGroup {
    static let id = "group.com.notesquick.app"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }

    // Keys shared with extensions.
    static let bookmarkKey = "notesFolderBookmark"
    static let pathKey = "notesFolderPath"
    static let extensionKey = "fileExtension"

    /// Copy any legacy values from standard defaults into the shared suite once,
    /// so existing installs keep their chosen folder after the move.
    static func migrateFromStandardIfNeeded() {
        let shared = defaults
        let std = UserDefaults.standard
        for key in [bookmarkKey, pathKey, extensionKey] {
            if shared.object(forKey: key) == nil, let value = std.object(forKey: key) {
                shared.set(value, forKey: key)
            }
        }
    }
}
