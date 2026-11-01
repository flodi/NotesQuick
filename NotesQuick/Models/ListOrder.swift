import Foundation

/// How a part of the list is sorted. Chosen in the settings, separately for pinned and other items.
enum ListSort: String, CaseIterable, Identifiable {
    case titleAscending, titleDescending, modifiedDescending, modifiedAscending

    var id: String { rawValue }

    var label: String {
        switch self {
        case .titleAscending: return L("Titolo, dalla A alla Z")
        case .titleDescending: return L("Titolo, dalla Z alla A")
        case .modifiedDescending: return L("Modifica, prima i più recenti")
        case .modifiedAscending: return L("Modifica, prima i meno recenti")
        }
    }

    func areInOrder(_ a: Note, _ b: Note) -> Bool {
        switch self {
        case .titleAscending, .titleDescending:
            let result = a.title.localizedStandardCompare(b.title)
            if result == .orderedSame { return a.modifiedDate > b.modifiedDate }
            return self == .titleAscending ? result == .orderedAscending : result == .orderedDescending
        case .modifiedDescending: return a.modifiedDate > b.modifiedDate
        case .modifiedAscending: return a.modifiedDate < b.modifiedDate
        }
    }
}

extension Note.Kind {
    /// Section title when the list is grouped by kind.
    var groupTitle: String {
        switch self {
        case .text: return L("Note")
        case .link: return L("Link")
        case .file: return L("File")
        }
    }

    var symbol: String {
        switch self {
        case .text: return "note.text"
        case .link: return "link"
        case .file: return "doc"
        }
    }
}

/// A titled part of the list: pinned items, then all the others (or one part per kind).
struct NoteSection: Identifiable {
    let id: String
    let title: String
    let notes: [Note]
}
