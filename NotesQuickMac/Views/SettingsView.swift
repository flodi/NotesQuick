import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var viewModel: NotesViewModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Generali") {
                Toggle("Apri al login", isOn: $launchAtLogin)
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

            Section("Cartella delle note") {
                HStack {
                    Text(viewModel.notesFolderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(Q.F.data(11.5, .regular))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: Q.R.box).fill(Q.C.sunken))

                    Button("Scegli…") {
                        chooseFolder()
                    }
                }

                Text("Le note sono salvate come file di testo in questa cartella.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Estensione dei file") {
                Picker("Estensione", selection: $viewModel.fileExtension) {
                    Text(".md").font(Q.F.data()).tag("md")
                    Text(".markdown").font(Q.F.data()).tag("markdown")
                    Text(".txt").font(Q.F.data()).tag("txt")
                }
                .pickerStyle(.radioGroup)

                Text("Cambiando estensione compaiono solo i file con la nuova estensione.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Tag") {
                Toggle("Nascondi i tag nell'editor", isOn: $viewModel.hideTagsInEditor)

                Text("Se attivo, i #tag sono nascosti nel testo e compaiono solo nella nuvola dei tag.")
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
        panel.message = "Scegli la cartella delle note"

        if panel.runModal() == .OK, let url = panel.url {
            viewModel.setNotesFolderFromPicker(url)
        }
    }
}
