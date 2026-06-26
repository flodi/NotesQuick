import SwiftUI

@main
struct NotesQuickiOSApp: App {
    @StateObject private var viewModel = NotesViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
