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
            Section("Cartella delle note") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(folderDisplayName)
                            .font(.body)
                        Text(viewModel.notesFolderPath)
                            .font(Q.F.data(11, .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Cambia") {
                        showFolderPicker = true
                    }
                }

                Text("Scegli da File la cartella in cui salvare le note. Funziona con iCloud Drive, Dropbox e altri provider.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Estensione dei file") {
                Picker("Estensione", selection: $viewModel.fileExtension) {
                    Text(".md").tag("md")
                    Text(".markdown").tag("markdown")
                    Text(".txt").tag("txt")
                }
                .pickerStyle(.segmented)

                Text("Cambiando estensione compaiono solo i file con la nuova estensione.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Tag") {
                Toggle("Nascondi i tag nell'editor", isOn: $viewModel.hideTagsInEditor)

                Text("Se attivo, i #tag sono nascosti nel testo e compaiono solo nella nuvola dei tag.")
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
