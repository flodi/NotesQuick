import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @State private var showFolderPicker = false

    var folderDisplayName: String {
        let path = viewModel.notesFolderPath
        if let range = path.range(of: "/Documents/", options: .backwards) {
            return String(path[range.upperBound...])
        }
        return (path as NSString).lastPathComponent
    }

    var body: some View {
        Form {
            Section("Notes Folder") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(folderDisplayName)
                            .font(.body)
                        Text(viewModel.notesFolderPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Change") {
                        showFolderPicker = true
                    }
                }

                Text("Choose a folder from Files to store your notes. Supports iCloud Drive, Dropbox, and other providers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("File Extension") {
                Picker("Extension", selection: $viewModel.fileExtension) {
                    Text(".md").tag("md")
                    Text(".markdown").tag("markdown")
                    Text(".txt").tag("txt")
                }
                .pickerStyle(.segmented)

                Text("Changing extension will only show files matching the new extension.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Tags") {
                Toggle("Hide tags in editor", isOn: $viewModel.hideTagsInEditor)

                Text("When enabled, #tags are hidden in the editor text and only shown in the tag cloud.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.setNotesFolderFromPicker(url)
            }
        }
    }
}
