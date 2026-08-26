import UIKit
import UniformTypeIdentifiers

/// Share extension: saves the shared URL, text, image or file into the NotesQuick
/// folder, then dismisses. Covers iOS and iPadOS.
final class ShareViewController: UIViewController {

    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemBackground
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        label.text = "Saving to NotesQuick…"
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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

        // 1. A real file (fileURL) — load the actual URL so we copy the real file
        //    with its real name, not a representation of the URL string.
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

        // 3. Plain text (check before generic data — text conforms to data).
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

        // 4. Image or other data → copy as a file (temp URL valid only in the closure).
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
        label.text = count > 0 ? "Saved to NotesQuick" : "Nothing to save"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
