import Foundation

/// Optional per-item scheduling: a "hide until" date (snooze — the item is hidden
/// from the list until then) and a "remind me on" date (a local notification).
struct ItemSchedule: Codable, Equatable {
    var hideUntil: Date?
    var remindAt: Date?

    var isEmpty: Bool { hideUntil == nil && remindAt == nil }

    /// Whether the item should currently be hidden from the main list.
    func isHidden(now: Date = Date()) -> Bool {
        if let h = hideUntil, h > now { return true }
        return false
    }
}

/// The schedule index lives as a hidden JSON file in the notes folder so it syncs
/// (e.g. via Dropbox) yet never shows up as an item. Keyed by file name.
enum ScheduleIndex {
    static let fileName = ".notesquick-meta.json"

    static func decode(_ data: Data) -> [String: ItemSchedule] {
        (try? JSONDecoder.iso.decode([String: ItemSchedule].self, from: data)) ?? [:]
    }

    static func encode(_ map: [String: ItemSchedule]) -> Data? {
        try? JSONEncoder.iso.encode(map)
    }
}

private extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

private extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}
