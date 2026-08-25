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
        let url = UTType.url.identifier
        let fileURL = UTType.fileURL.identifier
        let text = UTType.plainText.identifier

        if provider.hasItemConformingToTypeIdentifier(url),
           !provider.hasItemConformingToTypeIdentifier(fileURL) {
            provider.loadItem(forTypeIdentifier: url, options: nil) { item, _ in
                if let u = item as? URL, !u.isFileURL {
                    completion(NoteFolder.saveLink(u, title: nil) != nil)
                } else if let u = item as? URL {
                    completion(NoteFolder.copyFile(at: u) != nil)
                } else {
                    completion(false)
                }
            }
            return
        }

        for typeId in [fileURL, UTType.image.identifier, UTType.data.identifier]
        where provider.hasItemConformingToTypeIdentifier(typeId) {
            provider.loadFileRepresentation(forTypeIdentifier: typeId) { tempURL, _ in
                let ok = tempURL.map { NoteFolder.copyFile(at: $0) != nil } ?? false
                completion(ok)
            }
            return
        }

        if provider.hasItemConformingToTypeIdentifier(text) {
            provider.loadItem(forTypeIdentifier: text, options: nil) { item, _ in
                if let s = item as? String {
                    completion(NoteFolder.saveText(s, title: nil) != nil)
                } else {
                    completion(false)
                }
            }
            return
        }

        completion(false)
    }

    private func finish(count: Int) {
        label.stringValue = count > 0 ? "Saved to NotesQuick" : "Nothing to save"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
