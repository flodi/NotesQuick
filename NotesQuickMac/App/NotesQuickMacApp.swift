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

        Window("Preferenze", id: "settings") {
            SettingsView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 450, height: 520)
        .windowResizability(.contentSize)

        WindowGroup("Nota", id: "note-editor", for: String.self) { $noteId in
            NoteEditorView(noteId: noteId)
                .environmentObject(viewModel)
        }
        .defaultSize(width: 600, height: 400)
        .commands {
            CommandGroup(replacing: .saveItem) {
                Button("Salva") {
                    NotificationCenter.default.post(name: .saveCurrentNote, object: nil)
                }
                .keyboardShortcut("s")
            }
        }
    }
}
