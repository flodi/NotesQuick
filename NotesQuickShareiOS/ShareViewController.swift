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
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)

        label.text = L("Salvataggio in NotesQuick…")
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

        guard AppGroup.inboxURL() != nil else {
            return finish(L("Errore: App Group non accessibile"))
        }
        guard !providers.isEmpty else {
            return finish(L("Niente da salvare (0 elementi ricevuti)"))
        }

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

        group.notify(queue: .main) {
            if saved > 0 {
                self.finish(L("Salvato in NotesQuick (%@)", "\(saved)"))
            } else {
                let types = providers.first?.registeredTypeIdentifiers.prefix(4).joined(separator: ", ") ?? "?"
                self.finish(L("Fallito · tipi: %@ · %@", "\(types)", NoteFolder.lastError ?? L("nessun ramo")))
            }
        }
    }

    private func process(_ provider: NSItemProvider, completion: @escaping (Bool) -> Void) {
        let fileURLType = UTType.fileURL.identifier
        let textType = UTType.plainText.identifier

        // 1. A real file (fileURL) — copy the actual file with its name.
        if provider.hasItemConformingToTypeIdentifier(fileURLType) {
            provider.loadItem(forTypeIdentifier: fileURLType, options: nil) { item, _ in
                if let src = ShareViewController.fileURL(from: item) {
                    completion(NoteFolder.copyFile(at: src) != nil)
                } else {
                    NoteFolder.lastError = "file item non URL"
                    completion(false)
                }
            }
            return
        }

        // 2. A URL — loadObject(URL) is the reliable way to read public.url.
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, err in
                if let url = url, !url.isFileURL {
                    completion(NoteFolder.saveLink(url, title: nil) != nil)
                } else if let url = url {
                    completion(NoteFolder.copyFile(at: url) != nil)
                } else {
                    NoteFolder.lastError = "loadObject URL: \(err?.localizedDescription ?? "nil")"
                    completion(false)
                }
            }
            return
        }

        // 3. Plain text.
        if provider.hasItemConformingToTypeIdentifier(textType) {
            provider.loadItem(forTypeIdentifier: textType, options: nil) { item, _ in
                if let s = item as? String {
                    completion(NoteFolder.saveText(s, title: nil) != nil)
                } else if let d = item as? Data, let s = String(data: d, encoding: .utf8) {
                    completion(NoteFolder.saveText(s, title: nil) != nil)
                } else {
                    NoteFolder.lastError = "text item non String"
                    completion(false)
                }
            }
            return
        }

        // 4. Image or other data → copy as a file.
        for typeId in [UTType.image.identifier, UTType.data.identifier]
        where provider.hasItemConformingToTypeIdentifier(typeId) {
            provider.loadFileRepresentation(forTypeIdentifier: typeId) { tempURL, err in
                if let tempURL {
                    completion(NoteFolder.copyFile(at: tempURL) != nil)
                } else {
                    NoteFolder.lastError = "fileRep: \(err?.localizedDescription ?? "nil")"
                    completion(false)
                }
            }
            return
        }

        NoteFolder.lastError = "tipo non gestito"
        completion(false)
    }

    private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let u = item as? URL, u.isFileURL { return u }
        if let d = item as? Data, let u = URL(dataRepresentation: d, relativeTo: nil), u.isFileURL { return u }
        return nil
    }

    private func finish(_ message: String) {
        label.text = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
