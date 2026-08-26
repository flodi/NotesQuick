import Cocoa
import UniformTypeIdentifiers

/// macOS share extension: saves the shared URL, text, image or file into the
/// NotesQuick folder, then dismisses.
final class ShareViewController: NSViewController {

    private let label = NSTextField(labelWithString: "Saving to NotesQuick…")

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 110))
        label.font = .boldSystemFont(ofSize: 14)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 20),
        ])
        self.view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        handleShare()
    }

    private func handleShare() {
        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let providers = items.flatMap { $0.attachments ?? [] }
        guard !providers.isEmpty else { return finish(count: 0) }

        let group = DispatchGroup()
        var saved = 0
        let lock = NSLock()

        for provider in providers {
            group.enter()
            process(provider) { ok in
                if ok { lock.lock(); saved += 1; lock.unlock() }
                group.leave()
            }
        }

        group.notify(queue: .main) { self.finish(count: saved) }
    }

    private func process(_ provider: NSItemProvider, completion: @escaping (Bool) -> Void) {
        let urlType = UTType.url.identifier
        let fileURLType = UTType.fileURL.identifier
        let textType = UTType.plainText.identifier

        // 1. A real file — load the actual URL, copy the real file with its name.
        if provider.hasItemConformingToTypeIdentifier(fileURLType) {
            provider.loadItem(forTypeIdentifier: fileURLType, options: nil) { item, _ in
                let src = ShareViewController.fileURL(from: item)
                completion(src.map { NoteFolder.copyFile(at: $0) != nil } ?? false)
            }
            return
        }

        // 2. A web link.
        if provider.hasItemConformingToTypeIdentifier(urlType) {
            provider.loadItem(forTypeIdentifier: urlType, options: nil) { item, _ in
                if let u = item as? URL {
                    completion(NoteFolder.saveLink(u, title: nil) != nil)
                } else { completion(false) }
            }
            return
        }

        // 3. Plain text (before generic data — text conforms to data).
        if provider.hasItemConformingToTypeIdentifier(textType) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { item, _ in
                if let s = item as? String {
                    completion(NoteFolder.saveText(s, title: nil) != nil)
                } else if let d = item as? Data, let s = String(data: d, encoding: .utf8) {
                    completion(NoteFolder.saveText(s, title: nil) != nil)
                } else { completion(false) }
            }
            return
        }

        // 4. Image or other data → copy as a file.
        for typeId in [UTType.image.identifier, UTType.data.identifier]
        where provider.hasItemConformingToTypeIdentifier(typeId) {
            provider.loadFileRepresentation(forTypeIdentifier: typeId) { tempURL, _ in
                completion(tempURL.map { NoteFolder.copyFile(at: $0) != nil } ?? false)
            }
            return
        }

        completion(false)
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let u = item as? URL, u.isFileURL { return u }
        if let d = item as? Data, let u = URL(dataRepresentation: d, relativeTo: nil), u.isFileURL { return u }
        return nil
    }

    private func finish(count: Int) {
        label.stringValue = count > 0 ? "Saved to NotesQuick" : "Nothing to save"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
