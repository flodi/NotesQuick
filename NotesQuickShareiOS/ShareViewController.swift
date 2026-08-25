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
        let url = UTType.url.identifier
        let fileURL = UTType.fileURL.identifier
        let text = UTType.plainText.identifier

        // A web link (not a file URL).
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

        // Any file (image, PDF, document, …). loadFileRepresentation gives a temp
        // URL valid only inside the closure, so copy synchronously there.
        for typeId in [fileURL, UTType.image.identifier, UTType.data.identifier] where provider.hasItemConformingToTypeIdentifier(typeId) {
            provider.loadFileRepresentation(forTypeIdentifier: typeId) { tempURL, _ in
                let ok = tempURL.map { NoteFolder.copyFile(at: $0) != nil } ?? false
                completion(ok)
            }
            return
        }

        // Plain text.
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
        label.text = count > 0 ? "Saved to NotesQuick" : "Nothing to save"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
