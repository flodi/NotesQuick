import SwiftUI

#if os(macOS)
import Quartz

/// Embeds a native Quick Look preview (PDF, images, Office & iWork documents,
/// text, …) for a file item on macOS.
struct QuickLookPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.autostarts = true
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if (nsView.previewItem as? NSURL) as URL? != url {
            nsView.previewItem = url as NSURL
        }
    }
}
#else
import QuickLook

/// Embeds a native Quick Look preview for a file item on iOS/iPadOS.
struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#endif

/// A container that holds security-scoped access to the notes folder for as long
/// as the Quick Look preview is visible, so sandboxed file items can be read.
struct FilePreviewScreen: View {
    let url: URL
    @State private var accessURL: URL?

    var body: some View {
        QuickLookPreview(url: url)
            .onAppear { accessURL = FolderBookmark.beginAccess() }
            .onDisappear {
                FolderBookmark.endAccess(accessURL)
                accessURL = nil
            }
    }
}
