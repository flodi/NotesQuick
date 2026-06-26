import SwiftUI

@main
struct NotesQuickMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = NotesViewModel()

    var body: some Scene {
        MenuBarExtra("NotesQuick", image: "MenuBarIcon") {
            NoteListView()
                .environmentObject(viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Preferences", id: "settings") {
            SettingsView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 450, height: 260)
        .windowResizability(.contentSize)

        WindowGroup("Note Editor", id: "note-editor", for: String.self) { $noteId in
            NoteEditorView(noteId: noteId)
                .environmentObject(viewModel)
        }
        .defaultSize(width: 600, height: 400)
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    NotificationCenter.default.post(name: .saveCurrentNote, object: nil)
                }
                .keyboardShortcut("s")
            }
        }
    }
}
