import Foundation

/// File operations on the notes folder, coordinated with NSFileCoordinator.
/// The folder can belong to a file provider (iCloud Drive, other services in Files): plain
/// FileManager writes may never be noticed by the provider, so the change is not uploaded and
/// other devices never see it. Coordinating every write tells the provider about it.
enum CoordinatedFile {
    static func write(_ data: Data, to url: URL) {
        coordinate(url, .forReplacing) { try data.write(to: $0, options: .atomic) }
    }

    static func write(_ text: String, to url: URL) {
        write(Data(text.utf8), to: url)
    }

    static func delete(_ url: URL) {
        coordinate(url, .forDeleting) { try FileManager.default.removeItem(at: $0) }
    }

    @discardableResult
    static func copy(_ source: URL, to dest: URL) -> Bool {
        var ok = false
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], writingItemAt: dest,
                                       options: .forReplacing, error: &error) { src, dst in
            ok = (try? FileManager.default.copyItem(at: src, to: dst)) != nil
        }
        return ok
    }

    @discardableResult
    static func move(_ source: URL, to dest: URL) -> Bool {
        var ok = false
        var error: NSError?
        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: source, options: .forMoving, writingItemAt: dest,
                               options: .forReplacing, error: &error) { src, dst in
            coordinator.item(at: src, willMoveTo: dst)
            ok = (try? FileManager.default.moveItem(at: src, to: dst)) != nil
            if ok { coordinator.item(at: src, didMoveTo: dst) }
        }
        return ok
    }

    private static func coordinate(_ url: URL, _ options: NSFileCoordinator.WritingOptions, _ body: (URL) throws -> Void) {
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: options, error: &error) { try? body($0) }
    }
}
