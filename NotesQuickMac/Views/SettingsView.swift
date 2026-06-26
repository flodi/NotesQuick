import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section("Notes Folder") {
                HStack {
                    Text(viewModel.notesFolderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .background(Color.primary.opacity(0.04))
                        .cornerRadius(6)

                    Button("Choose...") {
                        chooseFolder()
                    }
                }

                Text("Notes are stored as text files in this folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("File Extension") {
                Picker("Extension", selection: $viewModel.fileExtension) {
                    Text(".md").tag("md")
                    Text(".markdown").tag("markdown")
                    Text(".txt").tag("txt")
                }
                .pickerStyle(.radioGroup)

                Text("Changing extension will only show files matching the new extension.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Tags") {
                Toggle("Hide tags in editor", isOn: $viewModel.hideTagsInEditor)

                Text("When enabled, #tags are hidden in the editor text and only shown in the tag cloud.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 300)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder for your notes"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setNotesFolderFromPicker(url)
        }
    }
}
