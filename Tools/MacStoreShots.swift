// Renders the Mac views off screen for the App Store screenshots, without launching the app
// (no menu bar item, no Dock icon). Built and run by Tools/mac-store-shots.sh.
//   MacStoreShots <out-dir> <note-title>
import AppKit
import SwiftUI

let out = URL(fileURLWithPath: CommandLine.arguments[1])
let wanted = CommandLine.arguments[2]

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
app.appearance = NSAppearance(named: .aqua)

let viewModel = NotesViewModel()
viewModel.loadNotes()

@MainActor
func render<V: View>(_ view: V, size: CGSize, name: String, scale: CGFloat = 3) {
    let host = NSHostingView(rootView: view.environmentObject(viewModel))
    host.frame = NSRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: NSRect(x: -20000, y: -20000, width: size.width, height: size.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: .aqua)
    window.backgroundColor = .windowBackgroundColor
    window.contentView = host
    window.orderFrontRegardless()
    RunLoop.current.run(until: Date().addingTimeInterval(1.5))
    host.layoutSubtreeIfNeeded()
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    host.cacheDisplay(in: host.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name + ".png"))
    window.orderOut(nil)
}

MainActor.assumeIsolated {
    render(NoteListView(), size: CGSize(width: 300, height: 400), name: "list")
    if let note = viewModel.notes.first(where: { $0.title.localizedCaseInsensitiveContains(wanted) }) {
        render(NoteEditorView(noteId: note.id), size: CGSize(width: 620, height: 470), name: "editor")
        render(SchedulePicker(note: note), size: CGSize(width: 360, height: 340), name: "schedule")
    }
    render(SettingsView(), size: CGSize(width: 450, height: 520), name: "settings")
}
