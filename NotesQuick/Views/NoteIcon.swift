import SwiftUI

/// SF Symbol for a list item, by kind and (for files) file type.
/// The glyph alone tells the kinds apart: colour is reserved for accent and states.
enum NoteIcon {
    static func symbol(for note: Note) -> String {
        switch note.kind {
        case .text: return "note.text"
        case .link: return "link"
        case .file: return symbolForFile(note.fileURL)
        }
    }

    private static func symbolForFile(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "heic", "heif", "tiff", "bmp", "webp": return "photo"
        case "doc", "docx", "pages", "rtf": return "doc.text"
        case "xls", "xlsx", "numbers", "csv": return "tablecells"
        case "ppt", "pptx", "key": return "rectangle.on.rectangle"
        case "zip", "rar", "7z", "gz": return "doc.zipper"
        case "mp3", "wav", "m4a", "aac", "flac": return "music.note"
        case "mp4", "mov", "m4v", "avi", "mkv": return "film"
        default: return "doc"
        }
    }
}
